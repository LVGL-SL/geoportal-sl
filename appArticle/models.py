from django.db import models
from useroperations.models import MbUser

# ============ Article Configuration Models ============

class ArticleConfig(models.Model):
    """Represents an article configuration (corresponds to one former JSON file)"""
    LANGUAGE_CHOICES = [
        ('de', 'Deutsch'),
        ('en', 'English'),
        ('fr', 'Français'),
        ('all', 'All Languages'),
    ]
    
    #Corresponds to the filename of the JSON file (without .json extension) and is used as a unique identifier for the article
    article_keyword = models.SlugField(unique=True, help_text="Unique identifier (e.g., 'geofachdatenuebersicht')")
    #new additions to support multilingual articles. If set to 'all', the article is considered language-agnostic and will be displayed for all languages.
    language = models.CharField(max_length=10, choices=LANGUAGE_CHOICES, default='all', help_text="Language of this article configuration")
    #new option to control whether the article is active and should be displayed in the frontend. If unchecked, the article will be hidden.
    is_active = models.BooleanField(default=True, help_text="If unchecked, this article will not be displayed")
    
    #3 new fields for metadata tracking: created, modified, and created_by. These fields will automatically track when the article was created and last modified, as well as which user created it.
    created = models.DateTimeField(auto_now_add=True)
    modified = models.DateTimeField(auto_now=True)
    created_by = models.ForeignKey(MbUser, on_delete=models.SET_NULL, null=True, blank=True, related_name='created_articles')
    
    class Meta:
        verbose_name = "Artikel/Seite"
        verbose_name_plural = "01. Artikel/Seiten"
        ordering = ['-modified']
        unique_together = [('article_keyword', 'language')]
    
    def __str__(self):
        return f"{self.article_keyword} ({self.get_language_display()})"
    
    def to_dict(self):
        """Convert to the format expected by templates"""
        return {
            "sections": [section.to_dict() for section in self.sections.all().order_by('order')]
        }
    
    def to_json_export(self):
        """Export article to JSON format for download/backup"""
        import json
        data = {
            "article_keyword": self.article_keyword,
            "language": self.language,
            "created": self.created.isoformat(),
            "modified": self.modified.isoformat(),
            "sections": [section.to_dict() for section in self.sections.all().order_by('order')]
        }
        return json.dumps(data, indent=4, ensure_ascii=False)


class ArticleSection(models.Model):
    """Represents a section within an article"""
    article = models.ForeignKey(ArticleConfig, on_delete=models.CASCADE, related_name='sections')
    title = models.CharField(max_length=255, blank=True)
    description = models.TextField(blank=True, help_text="Can include HTML")
    order = models.PositiveIntegerField(default=0)
    
    class Meta:
        verbose_name = "Abschnitt/Segment"
        verbose_name_plural = "02. Abschnitte/Segmente"
        ordering = ['order']
    
    def __str__(self):
        return f"Section: {self.order} - {self.title or '(No Title)'}"
    
    def to_dict(self):
        return {
            "title": self.title,
            "description": self.description,
            "content": [group.to_dict() for group in self.groups.all().order_by('order')]
        }


class SectionGroup(models.Model):
    """Represents a group within a section (accordion level 1)"""
    section = models.ForeignKey(ArticleSection, on_delete=models.CASCADE, related_name='groups')
    group_name = models.CharField(max_length=255)
    order = models.PositiveIntegerField(default=0)
    
    class Meta:
        ordering = ['order']
        verbose_name = "Dienst-/Item-Gruppe"
        verbose_name_plural = "03. Dienst-/Item-Gruppen"
    
    def __str__(self):
        return f"{self.section.title} - {self.group_name}"
    
    def to_dict(self):
        return {
            "group_name": self.group_name,
            "data": [item.to_dict() for item in self.items.all().order_by('order')]
        }


class GroupItem(models.Model):
    """Represents an item within a group (accordion level 2)"""
    group = models.ForeignKey(SectionGroup, on_delete=models.CASCADE, related_name='items')
    title = models.CharField(max_length=255)
    url = models.URLField(max_length=1000, blank=True, help_text="If set, becomes a link instead of expandable item")
    image_url = models.CharField(max_length=500, blank=True)
    order = models.PositiveIntegerField(default=0)
    
    class Meta:
        ordering = ['order']
        verbose_name = "Dienst-/Item"
        verbose_name_plural = "04. Dienste/Items"
    
    def __str__(self):
        return self.title
    
    def to_dict(self):
        data = {
            "title": self.title,
        }
        if self.url:
            data["url"] = self.url
        if self.image_url:
            data["image_url"] = self.image_url
        if self.links.exists():
            data["links"] = [link.to_dict() for link in self.links.all().order_by('order')]
        return data


class ItemLink(models.Model):
    """Represents a link within an item"""
    item = models.ForeignKey(GroupItem, on_delete=models.CASCADE, related_name='links')
    name = models.CharField(max_length=255)
    link = models.URLField(max_length=1000, blank=True, null=True)
    order = models.PositiveIntegerField(default=0)
    
    class Meta:
        verbose_name = "Link"
        verbose_name_plural = "05. Links"
        ordering = ['order']
    
    def __str__(self):
        return self.name
    
    def to_dict(self):
        return {
            "name": self.name,
            "link": self.link
        }
