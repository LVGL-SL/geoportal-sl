from django.db import models
from django.urls import reverse
from django.utils.translation import gettext_lazy as _

from useroperations.models import Gui as useroperations_Gui


class Gui(useroperations_Gui):
    class Meta:  # pyright: ignore[reportIncompatibleVariableOverride]
        proxy = True
        ordering = ["gui_id"]

    def __str__(self) -> str:
        return self.gui_id


class GuiMbGroup(models.Model):
    fkey_gui = models.OneToOneField(Gui, models.DO_NOTHING, primary_key=True)
    fkey_mb_group = models.ForeignKey("useroperations.MbGroup", models.DO_NOTHING)
    mb_group_type = models.CharField(max_length=50, blank=True, null=True)

    class Meta:
        managed = False
        db_table = "gui_mb_group"
        unique_together = (("fkey_gui", "fkey_mb_group"),)


class SecuredDocument(models.Model):
    path = models.CharField(max_length=255, verbose_name=_("Path"))
    gui = models.ForeignKey(Gui, on_delete=models.CASCADE, verbose_name=_("GUI"))

    id: int

    class Meta:
        verbose_name = _("Secured Document")
        verbose_name_plural = _("Secured Documents")

    def get_absolute_url(self) -> str:
        return reverse("secureddownload-document", args=[self.id])

    def __str__(self) -> str:
        return self.path


class SecuredFolder(models.Model):
    path = models.CharField(max_length=200, verbose_name=_("Path"))
    gui = models.ForeignKey("useroperations.Gui", on_delete=models.CASCADE, verbose_name=_("GUI"))
    include_subfolders = models.BooleanField(default=False, verbose_name=_("Include Subfolders"))

    id: int

    class Meta:
        verbose_name = _("Secured Folder")
        verbose_name_plural = _("Secured Folders")

    def get_absolute_url(self) -> str:
        return reverse("secureddownload-folder", args=[self.id, "..."])

    def __str__(self) -> str:
        return self.path
