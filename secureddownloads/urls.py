from django.urls import path

from .views import download_document, download_folder_document


urlpatterns = [
    path("document/<int:document_id>/", download_document, name="secureddownload-document"),
    path("folder/<int:folder_id>/<path:subpath>", download_folder_document, name="secureddownload-folder"),
]
