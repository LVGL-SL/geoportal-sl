from pathlib import Path

from django.core.exceptions import PermissionDenied
from django.http import FileResponse, Http404, HttpRequest

from .models import SecuredDocument, SecuredFolder
from .utils import check_gui_permission, serve_file


def download_document(request: HttpRequest, document_id: int) -> FileResponse:
    try:
        document = SecuredDocument.objects.get(id=document_id)
    except SecuredDocument.DoesNotExist:
        raise Http404

    if not check_gui_permission(request, document.gui):
        raise PermissionDenied

    path = Path(document.path)
    return serve_file(path)


def download_folder_document(request: HttpRequest, folder_id: int, subpath: str) -> FileResponse:
    try:
        folder = SecuredFolder.objects.get(id=folder_id)
    except SecuredFolder.DoesNotExist:
        raise Http404

    if not check_gui_permission(request, folder.gui):
        raise PermissionDenied

    # sanitize file path to prevent directory traversal attacks
    basepath = Path(folder.path).resolve()
    fullpath = (basepath / subpath).resolve()
    if not fullpath.is_relative_to(basepath):
        raise PermissionDenied
    if not folder.include_subfolders and fullpath.parent != basepath:
        raise PermissionDenied

    return serve_file(fullpath)
