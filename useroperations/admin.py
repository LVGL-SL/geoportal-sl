from django.contrib import admin
from .models import ApplicationSliderElement, LandingPageDispatch


admin.site.register(ApplicationSliderElement)

@admin.register(LandingPageDispatch)
class LandingPageDispatchAdmin(admin.ModelAdmin):
    pass
