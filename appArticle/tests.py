import os
import tempfile
from pathlib import Path

from django.test import SimpleTestCase

from appArticle.management.commands.migrate_articles_to_db import Command


class MigrateArticlesCommandTests(SimpleTestCase):
    def test_get_json_files_filters_to_requested_filename(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            temp_path = Path(tmpdir)
            (temp_path / 'alpha.json').write_text('{}', encoding='utf-8')
            (temp_path / 'beta.json').write_text('{}', encoding='utf-8')

            command = Command()
            selected_files = command._get_json_files(temp_path, 'beta.json')

            self.assertEqual([path.name for path in selected_files], ['beta.json'])

    def test_get_json_files_skips_broken_symlinks(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            temp_path = Path(tmpdir)
            (temp_path / 'alpha.json').write_text('{}', encoding='utf-8')
            broken_link = temp_path / 'broken.json'
            broken_link.symlink_to(temp_path / 'does-not-exist.json')

            command = Command()
            selected_files = command._get_json_files(temp_path, None)

            self.assertEqual([path.name for path in selected_files], ['alpha.json'])
