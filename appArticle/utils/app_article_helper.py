import json
from Geoportal.settings import BASE_DIR, DEBUG

from appArticle.models import ArticleConfig
from .app_article_json_converter import JsonConverter


def get_article_conf(conf_file_name, lang=False, is_url=False):
    """
    Returns article configuration from database (with JSON file fallback).
    
    This function first tries to fetch the article from the database,
    and falls back to JSON files for backward compatibility during migration.
    
    Args:
        conf_file_name (str): The article keyword/identifier
        lang (str): Language code (currently unused, for future multi-language support)
        is_url (bool): Not used, for compatibility
    
    Returns:
        dict: Article configuration in V3 format, or False if not found
    """
    
    if is_url:
        return False
    
    # Try to fetch from database first
    # Currently no multi-language support is implemented, so lang is not used
    try:
        article = ArticleConfig.objects.get(
            article_keyword=conf_file_name,
            is_active=True
        )
        return article.to_dict()
    except ArticleConfig.DoesNotExist:
        pass  # Fall back to JSON files
    except Exception:
        pass  # Silently fall back to JSON files in case of other errors
    
    # Fallback: Try paths in JSON files for backward compatibility
    paths = [
        BASE_DIR + '/appArticle/article_conf/' + conf_file_name + ".json"
    ]
    
    if DEBUG:
        paths.append(BASE_DIR + '/appArticle/article_conf/templates/' + conf_file_name + ".json")
    
    for config_path in paths:
        try:
            with open(config_path, encoding='utf-8') as file:
                json_data = json.load(file)
                # Normalize to V3 format if coming from JSON
                converter = JsonConverter()
                return converter.normalize(json_data)
        except Exception:
            continue
    
    return False
