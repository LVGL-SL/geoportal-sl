"""
Management command to migrate JSON article configurations to database models.

Usage:
    python manage.py migrate_articles_to_db                          # Dry-run (shows what would be migrated)
    python manage.py migrate_articles_to_db --commit                  # Execute migration
    python manage.py migrate_articles_to_db --commit --backup         # Execute and backup JSON files
    python manage.py migrate_articles_to_db --commit --delete         # Execute and delete JSON files
    python manage.py migrate_articles_to_db --commit --filename geofachdatenuebersicht.json
"""

import json
import os
import shutil
from pathlib import Path

from django.core.management.base import BaseCommand

from Geoportal.settings import BASE_DIR
from appArticle.models import (
    ArticleConfig, 
    ArticleSection, 
    SectionGroup, 
    GroupItem, 
    ItemLink
)
from appArticle.utils.app_article_json_converter import JsonConverter


class Command(BaseCommand):
    help = 'Migrate JSON article configurations to Django database models'

    def add_arguments(self, parser):
        parser.add_argument(
            '--commit',
            action='store_true',
            help='Actually perform the migration (default is dry-run)',
        )
        parser.add_argument(
            '--backup',
            action='store_true',
            help='Create backup of JSON files before migration',
        )
        parser.add_argument(
            '--delete',
            action='store_true',
            help='Delete JSON files after successful migration',
        )
        parser.add_argument(
            '--language',
            type=str,
            default='all',
            help='Language code for the imported articles (default: all)',
        )
        parser.add_argument(
            '--filename',
            type=str,
            default=None,
            help='Only process one article file by its filename (for example: geofachdatenuebersicht.json)',
        )

    def handle(self, *args, **options):
        is_dry_run = not options['commit']
        backup = options['backup']
        delete_files = options['delete']
        language = options['language']
        filename = options['filename']
        
        if is_dry_run:
            self.stdout.write(self.style.WARNING('DRY-RUN MODE: No data will be written to database'))
            self.stdout.write('')
        
        # Find article configuration directory
        base_dir = Path(BASE_DIR)
        article_conf_dir = base_dir / 'appArticle' / 'article_conf'
        
        if not article_conf_dir.exists():
            self.stdout.write(self.style.ERROR(f'Article conf directory not found: {article_conf_dir}'))
            return
        
        self.stdout.write(f'Scanning directory: {article_conf_dir}')
        
        json_files = self._get_json_files(article_conf_dir, filename)
        if not json_files:
            self.stdout.write(self.style.WARNING('No JSON files found to migrate'))
            return
        
        self.stdout.write(f'Found {len(json_files)} JSON files to migrate:')
        self.stdout.write('')
        
        converter = JsonConverter()
        success_count = 0
        failed_count = 0
        skipped_count = 0
        
        for json_file in json_files:
            try:
                self._process_file(
                    json_file, 
                    converter, 
                    is_dry_run, 
                    backup, 
                    delete_files,
                    language
                )
                success_count += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'✗ Failed: {json_file.name} - {str(e)}'))
                failed_count += 1
        
        # Summary
        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('=' * 60))
        self.stdout.write(self.style.SUCCESS(f'Migration Summary:'))
        self.stdout.write(self.style.SUCCESS(f'  Successful: {success_count}'))
        if failed_count > 0:
            self.stdout.write(self.style.ERROR(f'  Failed: {failed_count}'))
        if skipped_count > 0:
            self.stdout.write(self.style.WARNING(f'  Skipped: {skipped_count}'))
        
        if is_dry_run:
            self.stdout.write('')
            self.stdout.write(self.style.WARNING('DRY-RUN completed. To perform actual migration, use --commit flag'))
            self.stdout.write(self.style.WARNING('Example: python manage.py migrate_articles_to_db --commit --backup'))

    def _get_json_files(self, article_conf_dir, filename=None):
        """Return JSON files from the article config directory, optionally filtered by filename."""
        if filename:
            normalized_filename = filename if filename.endswith('.json') else f'{filename}.json'
            candidate = article_conf_dir / normalized_filename

            if not candidate.exists():
                return []
            if candidate.is_symlink() and not os.path.exists(candidate):
                return []
            if candidate.is_file():
                return [candidate]
            return []

        json_files = []
        for path in sorted(article_conf_dir.glob('*.json')):
            try:
                if path.is_symlink() and not os.path.exists(path):
                    continue
                if path.is_file():
                    json_files.append(path)
            except OSError:
                continue

        return json_files

    def _process_file(self, json_file, converter, is_dry_run, backup, delete_files, language):
        """Process a single JSON file and migrate to database"""
        
        self.stdout.write(f'Processing {json_file.name}...')
        
        # Load and validate JSON
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except json.JSONDecodeError as e:
            raise Exception(f'Invalid JSON: {e}')
        except IOError as e:
            raise Exception(f'Cannot read file: {e}')
        
        # Normalize to V3 format
        normalized = converter.normalize(data)
        
        article_keyword = json_file.stem
        
        if not is_dry_run:
            # Create or update article
            article, created = ArticleConfig.objects.update_or_create(
                article_keyword=article_keyword,
                language=language,
                defaults={'is_active': True}
            )
            
            # Clear existing sections (in case of update)
            article.sections.all().delete()
            
            # Import sections
            for section_idx, section_data in enumerate(normalized.get('sections', [])):
                section = ArticleSection.objects.create(
                    article=article,
                    title=section_data.get('title', ''),
                    description=section_data.get('description', ''),
                    order=section_idx
                )
                
                # Import groups
                for group_idx, group_data in enumerate(section_data.get('content', [])):
                    group = SectionGroup.objects.create(
                        section=section,
                        group_name=group_data.get('group_name', ''),
                        order=group_idx
                    )
                    
                    # Import items
                    for item_idx, item_data in enumerate(group_data.get('data', [])):
                        item = GroupItem.objects.create(
                            group=group,
                            title=item_data.get('title', ''),
                            url=item_data.get('url', ''),
                            image_url=item_data.get('image_url', ''),
                            order=item_idx
                        )
                        
                        # Import links
                        for link_idx, link_data in enumerate(item_data.get('links', [])):
                            ItemLink.objects.create(
                                item=item,
                                name=link_data.get('name', ''),
                                link=link_data.get('link', ''),
                                order=link_idx
                            )
        
        # Handle file operations (backup/delete)
        if not is_dry_run:
            if backup:
                backup_path = json_file.with_suffix('.json.bak')
                if backup_path.exists():
                    self.stdout.write(self.style.WARNING(f'  Backup file already exists: {backup_path.name}'))
                else:
                    shutil.copy2(json_file, backup_path)
                    self.stdout.write(self.style.SUCCESS(f'  ✓ Backed up to {backup_path.name}'))
            
            if delete_files:
                json_file.unlink()
                self.stdout.write(self.style.SUCCESS(f'  ✓ Deleted {json_file.name}'))
        
        self.stdout.write(self.style.SUCCESS(f'  ✓ Migrated: {article_keyword}'))
