import pytest
from mixer.backend.django import mixer
pytestmark = pytest.mark.django_db

from ..models import Navigation


# Tests start here
class TestNavigation:
    def test_model(self):
        obj = mixer.blend('useroperations.Navigation')
        assert obj.pk == 1

    def test_str(self):
        obj = mixer.blend('useroperations.Navigation', name="Home")
        assert str(obj) == "Home"
