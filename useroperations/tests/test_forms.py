import pytest

from ..forms import LoginForm

pytestmark = pytest.mark.django_db


# Tests start here
class TestLoginForm:
    def test__empty_form(self):
        form_data = {}
        form = LoginForm(data=form_data)
        assert form.is_valid(
        ) is False, "Should be invalid if no data is given"

    def test__empty_username_field(self):
        form_data = {
            'password': 'supersafe',
        }
        form = LoginForm(data=form_data)
        assert form.is_valid(
        ) is False, "Should be invalid with no username given"

    def test__empty_password_field(self):
        form_data = {
            'name': 'Foo',
        }
        form = LoginForm(data=form_data)
        assert form.is_valid(
        ) is False, "Should be invalid with no password given"

    def test__filled_form(self):
        form_data = {
            'name': 'Foo',
            'password': 'supersafe',
        }
        form = LoginForm(data=form_data)
        assert form.is_valid(
        ) is True, "Should be valid if all fields are filled correctly"
