import json
from collections import defaultdict
from pathlib import Path
import os
import shutil

class JsonConverter:
    """Converts app-articles"""
    
    def __init__(self, article_conf_path=None):
        """
        Initialization - set article_conf path only for script execution.
        
        Args:
            article_conf_path: Path to article_conf directory. If None, uses relative path from script location.
        """
        if article_conf_path is None:
            # Relative path from this file's location to convert article_conf-files
            # if wanted set condition below to True
            if False:
                current_file = Path(__file__).resolve()
                self.article_conf_path = current_file.parent.parent / "article_conf" #/ "templates"
        else:
            self.article_conf_path = Path(article_conf_path)

    def normalize(self, json_data):
        """
        Detects the version of the article JSON structure and converts it to V3.
        
        Args:
            json_data: The loaded JSON data
            
        Returns:
            JSON data in version 3 format
        """
        # Already in current format
        if "sections" in json_data:
            return json_data
        
        # Version 2: article_title + article_content (grouped)
        if "article_content" in json_data and isinstance(json_data.get("article_content"), list):
            # Check if article_content contains group_name (Version 2 structure)
            if json_data["article_content"] and "group_name" in json_data["article_content"][0]:
                return self._convert_v2_to_v3(json_data)
        
        # Version 1: article_title + flat data with group property
        if "data" in json_data and isinstance(json_data.get("data"), list):
            return self._convert_v1_to_v3(json_data)
        
        # Unknown format - return as-is
        return json_data

    def _convert_v1_to_v3(self, json_data):
        """
        Convert Version 1 format to Version 3
        V1: Flat list with group property on each item
        V3: Sections with grouped content
        """
        # Group items by their group name
        grouped_data = defaultdict(list)
        for item in json_data.get("data", []):
            group_name = item.get("group", "Unkategorisiert")
            # Create new item without group field
            new_item = {k: v for k, v in item.items() if k != "group"}
            grouped_data[group_name].append(new_item)
        
        # Convert grouped data to list of group objects
        content = []
        for group_name, items in grouped_data.items():
            group_obj = {
                "group_name": group_name,
                "data": items
            }
            content.append(group_obj)
        
        # Create section from article metadata
        section = {
            "title": json_data.get("article_title", ""),
            "description": json_data.get("article_description", ""),
            "content": content
        }
        
        return {"sections": [section]}

    def _convert_v2_to_v3(self, json_data):
        """
        Convert Version 2 format to Version 3
        V2: article_title + article_content (already grouped)
        V3: Sections with grouped content
        """
        # Create section from article metadata and content
        section = {
            "title": json_data.get("article_title", ""),
            "description": json_data.get("article_description", ""),
            "content": json_data.get("article_content", [])
        }
        
        return {"sections": [section]}

    def convert_file(self, file_path):
        """
        Convert a single JSON file from disk
        
        Args:
            file_path: Path to the JSON file to convert
            
        Returns:
            bool: True if successful, False otherwise
        """
        # Resolve symlink if it exists
        real_path = Path(file_path).resolve()
        
        try:
            with open(real_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except json.JSONDecodeError as e:
            return False
        except IOError as e:
            return False
        
        # Normalize the data - convert to V3
        converted_data = self.normalize(data)
        
        # Create backup of original file
        backup_path = real_path.with_suffix('.json.bak')
        if backup_path.exists():
            return False
        
        try:
            if real_path.is_symlink():
                # For symlinks, copy the content instead of renaming
                shutil.copy2(real_path, backup_path)
            else:
                os.rename(real_path, backup_path)
        except OSError as e:
            return False
        
        # Write converted data
        try:
            with open(real_path, 'w', encoding='utf-8') as f:
                json.dump(converted_data, f, indent=4, ensure_ascii=False)
            return True
        except IOError as e:
            # Restore backup if write failed
            if backup_path.exists():
                os.rename(backup_path, real_path)
            return False

    def convert_all_files(self, folder_path=None):
        """
        Convert all JSON files in a directory
        
        Args:
            folder_path: Path to folder containing JSON files. If None, uses self.article_conf_path
        """

        if folder_path is None:
            if not hasattr(self, 'article_conf_path') or self.article_conf_path is None:
                raise ValueError("No folder path provided and no default article_conf_path set")
            search_path = self.article_conf_path
        else:
            search_path = Path(folder_path)
        
        json_files = list(search_path.glob('*.json'))
        
        if not json_files:
            return
        
        #TODO: Add logging 
        success_count = 0
        failed_count = 0
        
        for file_path in json_files:
            if self.convert_file(file_path):
                success_count += 1
            else:
                failed_count += 1
        
