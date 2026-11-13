from pathlib import Path

from django.http import FileResponse, Http404, HttpRequest

from Geoportal.settings import SESSION_NAME
from Geoportal.utils.php_session_data import get_mapbender_session_by_memcache
from useroperations.models import Gui, GuiMbUser, MbUserMbGroup

from .models import GuiMbGroup


def check_gui_permission(request: HttpRequest, gui: Gui) -> bool:
    if not (session_id := request.COOKIES.get(SESSION_NAME)):
        return False
    if not (session_data := get_mapbender_session_by_memcache(session_id)):
        return False
    user_id = int(session_data[b"mb_user_id"])  # type: ignore

    # Check if user has direct permission to the GUI
    if GuiMbUser.objects.filter(fkey_mb_user=user_id, fkey_gui=gui).exists():
        return True

    # check if user has permission to the GUI through a group
    groups = MbUserMbGroup.objects.filter(fkey_mb_user=user_id).values_list("fkey_mb_group", flat=True)
    return GuiMbGroup.objects.filter(fkey_gui=gui, fkey_mb_group__in=groups).exists()


def serve_file(path: Path) -> FileResponse:
    if path.exists() and path.is_file():
        return FileResponse(path.open("rb"), filename=path.name)
    raise Http404
