from django.contrib import admin
from .models import (
    ArticleConfig,
    ArticleSection,
    SectionGroup,
    GroupItem,
    ItemLink,
)
from useroperations.models import MbUser
from django.contrib import admin
from django.urls import path
# from nested_admin import NestedTabularInline, NestedStackedInline, NestedModelAdmin


from django.db.models import Count

# ============ Article Configuration Admin (NESTED) ============

# class ItemLinkInline(NestedTabularInline):
#     """Level  5"""
#     model = ItemLink
#     extra = 1
#     fields = ('name', 'link', 'order')
#     ordering = ('order',)


# class GroupItemInline(NestedStackedInline):
#     """Level  4"""
#     model = GroupItem
#     extra = 1
#     fields = ('title', 'url', 'image_url', 'order')
#     inlines = [ItemLinkInline]  
#     ordering = ('order',)


# class SectionGroupInline(NestedStackedInline):
#     """Level  3"""
#     model = SectionGroup
#     extra = 1
#     fields = ('group_name', 'order')
#     inlines = [GroupItemInline]  
#     ordering = ('order',)


# class ArticleSectionInline(NestedStackedInline):
#     """Level  2"""
#     model = ArticleSection
#     extra = 1
#     fields = ('title', 'description', 'order')
#     inlines = [SectionGroupInline] 
#     ordering = ('order',)


# @admin.register(ArticleConfig)
# class ArticleConfigAdmin(NestedModelAdmin):
#     """Tab for articles:
    
#     Hierarchy:
#     Article (this level) 
#     └─ Sections (ArticleSectionInline) [Level 1]
#        └─ Groups (SectionGroupInline) [Level 2]
#           └─ Items (GroupItemInline) [Level 3]
#              └─ Links (ItemLinkInline) [Level 4]
#     """
#     list_display = ('article_keyword', 'language', 'is_active', 'modified')
#     list_filter = ('is_active', 'language', 'modified')
#     search_fields = ('article_keyword',)
#     readonly_fields = ('created', 'modified', 'created_by')
#     inlines = [ArticleSectionInline]
    
#     fieldsets = (
#         ('Basic Information', {
#             'fields': ('article_keyword', 'language', 'is_active')
#         }),
#         ('Metadata', {
#             'fields': ('created', 'modified', 'created_by'),
#             'classes': ('collapse',)
#         }),
#     )
    
#     def save_model(self, request, obj, form, change):
#         """Automatically set created_by on creation if a matching MbUser exists."""
#         if not change:  # New object
#             obj.created_by = None
#             if getattr(request, 'user', None) and getattr(request.user, 'is_authenticated', False):
#                 username = request.user.get_username()
#                 if username:
#                     try:
#                         obj.created_by = MbUser.objects.get(mb_user_name=username)
#                     except MbUser.DoesNotExist:
#                         obj.created_by = None
#         super().save_model(request, obj, form, change)
    
#     def get_urls(self):
#         """Add custom URLs for JSON export and view"""
#         urls = super().get_urls()
#         custom_urls = [
#             path('<int:article_id>/export-json/', 
#                  self.admin_site.admin_view(self.export_json_view),
#                  name='useroperations_articleconfig_export_json'),
#             path('<int:article_id>/view-json/', 
#                  self.admin_site.admin_view(self.view_json),
#                  name='useroperations_articleconfig_view_json'),
#         ]
#         return custom_urls + urls
    
#     def export_json_view(self, request, article_id):
#         """Export article configuration as JSON file"""
#         try:
#             article = ArticleConfig.objects.get(pk=article_id)
#             json_content = article.to_json_export()
            
#             response = HttpResponse(json_content, content_type='application/json')
#             response['Content-Disposition'] = f'attachment; filename="{article.article_keyword}.json"'
#             return response
#         except ArticleConfig.DoesNotExist:
#             return HttpResponse("Article not found", status=404)
    
#     def view_json(self, request, article_id):
#         """View article configuration as JSON (without download)"""
#         try:
#             article = ArticleConfig.objects.get(pk=article_id)
#             json_content = article.to_json_export()
            
#             return HttpResponse(json_content, content_type='application/json')
#         except ArticleConfig.DoesNotExist:
#             return HttpResponse("Article not found", status=404)

# ============ Article Configuration Admin (Flat) ============

class ArticleSectionInline(admin.TabularInline):
    model = ArticleSection
    extra = 0
    fields = (
        "order",
        "title",
        "description",
    )
    ordering = ("order",)
    show_change_link = True


@admin.register(ArticleConfig)
class ArticleConfigAdmin(admin.ModelAdmin):
    list_display = (
        "article_keyword",
        "language",
        "is_active",
        "section_count",
        "modified",
    )

    list_filter = (
        "language",
        "is_active",
    )

    search_fields = (
        "article_keyword",
    )

    readonly_fields = (
        "created",
        "modified",
        "created_by",
    )

    inlines = [
        ArticleSectionInline,
    ]

    fieldsets = (
        (
            "General",
            {
                "fields": (
                    "article_keyword",
                    "language",
                    "is_active",
                )
            },
        ),
        (
            "Metadata",
            {
                "classes": ("collapse",),
                "fields": (
                    "created",
                    "modified",
                    "created_by",
                ),
            },
        ),
    )

    def save_model(self, request, obj, form, change):
        """Automatically set created_by on creation if a matching MbUser exists."""
        if not change:  # New object
            obj.created_by = None
            if getattr(request, 'user', None) and getattr(request.user, 'is_authenticated', False):
                username = request.user.get_username()
                if username:
                    try:
                        obj.created_by = MbUser.objects.get(mb_user_name=username)
                    except MbUser.DoesNotExist:
                        obj.created_by = None
        super().save_model(request, obj, form, change)

    def get_queryset(self, request):
        queryset = super().get_queryset(request)
        return queryset.annotate(
            _section_count=Count("sections")
        )

    @admin.display(description="Sections")
    def section_count(self, obj):
        return obj._section_count



class SectionGroupInline(admin.TabularInline):
    model = SectionGroup
    extra = 0
    fields = (
        "order",
        "group_name",
    )
    ordering = ("order",)
    show_change_link = True


@admin.register(ArticleSection)
class ArticleSectionAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "article",
        "order",
    )

    list_filter = (
        "article",
    )

    search_fields = (
        "title",
        "article__article_keyword",
    )

    inlines = [
        SectionGroupInline,
    ]


class GroupItemInline(admin.TabularInline):
    model = GroupItem
    extra = 0

    fields = (
        "order",
        "title",
        "url",
        "image_url",
    )

    ordering = ("order",)
    show_change_link = True

@admin.register(SectionGroup)
class SectionGroupAdmin(admin.ModelAdmin):
    list_display = (
        "group_name",
        "section",
        "order",
    )

    search_fields = (
        "group_name",
    )

    list_filter = (
        "section__article",
    )

    inlines = [
        GroupItemInline,
    ]


class ItemLinkInline(admin.TabularInline):
    model = ItemLink
    extra = 0
    fields = (
        "order",
        "name",
        "link",
    )
    ordering = ("order",)


@admin.register(GroupItem)
class GroupItemAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "group",
        "order",
        "url",
    )

    search_fields = (
        "title",
    )

    list_filter = (
        "group__section__article",
    )

    inlines = [
        ItemLinkInline,
    ]


# @admin.register(ItemLink)
# class ItemLinkAdmin(admin.ModelAdmin):
#     list_display = (
#         "name",
#         "item",
#         "order",
#         "link",
#     )

#     search_fields = (
#         "name",
#     )
