import pytest
from mixer.backend.django import mixer
pytestmark = pytest.mark.django_db

from ..models import Navigation, ApplicationSliderElement


# Tests start here
class TestNavigation:
    def test_model(self):
        obj = mixer.blend('useroperations.Navigation')
        assert obj.pk == 1

    def test_str(self):
        obj = mixer.blend('useroperations.Navigation', name="Home")
        assert str(obj) == "Home"


class TestApplicationSliderElement:
    def test_model(self):
        obj = mixer.blend('useroperations.ApplicationSliderElement')
        assert obj.pk == 1

    def test_str(self):
        obj = mixer.blend('useroperations.ApplicationSliderElement', title="Slider Element 1")
        assert str(obj) == "Slider Element 1"

    def test_validate_types(self):
        obj = mixer.blend('useroperations.ApplicationSliderElement')
        assert type(obj.title) is str
        assert type(obj.anchor_href) is str
        assert type(obj.image_src) is str

    def test_create_multiple_objects(self):
        objects = []
        for _ in range(20):
            objects.append(mixer.blend('useroperations.ApplicationSliderElement'))
        
        assert type(objects[10].title) is str
        assert len(objects) == 20
       