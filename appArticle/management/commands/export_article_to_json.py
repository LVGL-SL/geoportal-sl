"""
Management command to export article configurations to JSON format.

Usage:
    python manage.py export_article_to_json geofachdatenuebersicht
    python manage.py export_article_to_json --all
    python manage.py export_article_to_json --all --output=/tmp/articles_backup/
"""

from django.core.management.base import BaseCommand
from pathlib import Path
from appArticle.models import ArticleConfig


class Command(BaseCommand):
    help = 'Export article configurations from database to JSON files'

    def add_arguments(self, parser):
        parser.add_argument(
            'article_keyword',
            nargs='?',
            help='Article keyword to export (e.g., "geobasisdatenuebersicht")',
        )
        parser.add_argument(
            '--all',
            action='store_true',
            help='Export all articles',
        )
        parser.add_argument(
            '--output',
            type=str,
            default='.',
            help='Output directory (default: current directory)',
        )
        parser.add_argument(
            '--language',
            type=str,
            help='Filter by language (e.g., "de", "en")',
        )

    def handle(self, *args, **options):
        article_keyword = options.get('article_keyword')
        export_all = options['all']
        output_dir = Path(options['output'])
        language_filter = options.get('language')
        
        # Validate options
        if not export_all and not article_keyword:
            self.stdout.write(
                self.style.ERROR(
                    'Either provide an article_keyword or use --all flag'
                )
            )
            return
        
        # Create output directory if it doesn't exist
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # Get articles to export
        if export_all:
            articles = ArticleConfig.objects.all()
            if language_filter:
                articles = articles.filter(language=language_filter)
        else:
            articles = ArticleConfig.objects.filter(article_keyword=article_keyword)
            if language_filter:
                articles = articles.filter(language=language_filter)
        
        if not articles.exists():
            self.stdout.write(
                self.style.WARNING('No articles found to export')
            )
            return
        
        success_count = 0
        failed_count = 0
        
        for article in articles:
            try:
                json_content = article.to_json_export()
                
                # Determine filename
                if article.language != 'all':
                    filename = f"{article.article_keyword}_{article.language}.json"
                else:
                    filename = f"{article.article_keyword}.json"
                
                output_file = output_dir / filename
                
                # Write file
                with open(output_file, 'w', encoding='utf-8') as f:
                    f.write(json_content)
                
                self.stdout.write(
                    self.style.SUCCESS(
                        f'✓ Exported: {article.article_keyword} → {output_file}'
                    )
                )
                success_count += 1
            
            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(
                        f'✗ Failed to export {article.article_keyword}: {str(e)}'
                    )
                )
                failed_count += 1
        
        # Summary
        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('=' * 60))
        self.stdout.write(self.style.SUCCESS(f'Export Summary:'))
        self.stdout.write(self.style.SUCCESS(f'  Successful: {success_count}'))
        if failed_count > 0:
            self.stdout.write(self.style.ERROR(f'  Failed: {failed_count}'))
        self.stdout.write(self.style.SUCCESS(f'  Output directory: {output_dir.absolute()}'))
