from django.contrib import admin
from django.utils.translation import gettext_lazy as _

from Geoportal.settings import HOSTNAME

from .models import SecuredDocument, SecuredFolder


@admin.register(SecuredDocument)
class SecuredDocumentAdmin(admin.ModelAdmin):
    list_display = ("id", "path", "gui", "external_url")
    list_display_links = ("id", "path")

    @admin.display(description=_("External URL"))
    def external_url(self, obj: SecuredDocument) -> str:
        return f"https://{HOSTNAME}{obj.get_absolute_url()}"


@admin.register(SecuredFolder)
class SecuredFolderAdmin(admin.ModelAdmin):
    list_display = ("id", "path", "gui", "include_subfolders", "external_url")
    list_display_links = ("id", "path")

    @admin.display(description=_("External URL"))
    def external_url(self, obj: SecuredFolder) -> str:
        return f"https://{HOSTNAME}{obj.get_absolute_url()}"
