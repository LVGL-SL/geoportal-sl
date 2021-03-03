from .models import ApplicationSliderElement
from django.contrib import admin
from .models import ApplicationSliderElement, LandingPageDispatch


@admin.register(ApplicationSliderElement)
class ApplicationSliderElementAdmin(admin.ModelAdmin):
    list_display = ('rank', 'title')
    list_display_links = ('title', )
    list_editable = ('rank', )
    ordering = ('rank', )


@admin.register(LandingPageDispatch)
class LandingPageDispatchAdmin(admin.ModelAdmin):
    pass
