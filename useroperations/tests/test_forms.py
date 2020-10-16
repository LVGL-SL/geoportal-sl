import pytest
import random
import string

from ..forms import (LoginForm, ChangeProfileForm, PasswordResetForm,
                     DeleteProfileForm)

pytestmark = pytest.mark.django_db


def get_random_string(length):
    # Random string with the combination of lower and upper case
    letters = string.ascii_letters
    result_str = ''.join(random.choice(letters) for i in range(length))
    return result_str


# Tests start here
class TestLoginForm:
    def test_empty_form(self):
        form_data = {}
        form = LoginForm(data=form_data)
        assert form.is_valid(
        ) is False, "Should be invalid if no data is given"

    def test_empty_username_field(self):
        form_data = {
            'password': 'supersafe',
        }
        form = LoginForm(data=form_data)
        assert form.is_valid(
        ) is False, "Should be invalid with no username given"

    def test_empty_password_field(self):
        form_data = {
            'name': 'Foo',
        }
        form = LoginForm(data=form_data)
        assert form.is_valid(
        ) is False, "Should be invalid with no password given"

    def test_filled_form(self):
        form_data = {
            'name': 'Foo',
            'password': 'supersafe',
        }
        form = LoginForm(data=form_data)
        assert form.is_valid(
        ) is True, "Should be valid if all fields are filled correctly"


class TestChangeProfileForm:
    def test_empty_form(self):
        form_data = {}
        form = ChangeProfileForm(data=form_data)
        assert form.is_valid(
        ) is False, "Should be invalid if no data is given"

    def test_only_email_field(self):
        form_data = {
            'email': 'user@mail.com',  # This is the only required field
        }
        form = ChangeProfileForm(data=form_data)
        assert form.is_valid(
        ) is True, "Should be valid if a valid email is given"

    def test_invalid_email_address(self):
        form_data = {
            'email': 'invalid_mail_address',
        }
        form = ChangeProfileForm(data=form_data)
        assert form.is_valid(
        ) is False, "Should be invalid if no valid email is given"

    def test_field_to_long(self):
        form_data = {
            'email': 'user@mail.com',  # This is the only required field
            'organization': get_random_string(101),
            'department': get_random_string(101),
            'phone': get_random_string(101),
            'description': get_random_string(1001),
            'preferred_gui': get_random_string(101),
        }
        form = ChangeProfileForm(data=form_data)
        assert form.is_valid(
        ) is False, "Should be invalid if field length above 100"

    def test_field_not_to_long(self):
        form_data = {
            'email': 'user@mail.com',  # This is the only required field
            'organization': get_random_string(100),
            'department': get_random_string(100),
            'phone': get_random_string(100),
            'description': get_random_string(1000),
            'preferred_gui': get_random_string(100),
        }
        form = ChangeProfileForm(data=form_data)
        assert form.is_valid(
        ) is True, "Should be valid if field length not above 100"

    def test_password_fields(self):
        form_data = {
            'email': 'user@mail.com',  # This is the only required field
            'oldpassword': get_random_string(20),
            'password': get_random_string(20),
            'passwordconfirm': get_random_string(20),
        }
        form = ChangeProfileForm(data=form_data)
        assert form.is_valid(
        ) is True, "Should be valid if a valid email is given"

    def test_full_form_valid(self):
        form_data = {
            'email': 'user@mail.com',  # This is the only required field
            'oldpassword': get_random_string(20),
            'password': get_random_string(20),
            'passwordconfirm': get_random_string(20),
            'organization': get_random_string(100),
            'department': get_random_string(100),
            'phone': get_random_string(100),
            'description': get_random_string(1000),
            'preferred_gui': get_random_string(100),
            'newsletter': False,
            'survey': False,
            'create_digest': False,
            'dsgvo': True,
        }
        form = ChangeProfileForm(data=form_data)
        assert form.is_valid(
        ) is True, "Should be valid if field length not above 100"


class TestPasswordResetForm:
    def test_empty_form(self):
        form_data = {}
        form = PasswordResetForm(data=form_data)
        assert form.is_valid(
        ) is False, "Should be invalid if no data is given"

    def test_empty_username_field(self):
        form_data = {
            'email': 'user@mail.com',
        }
        form = LoginForm(data=form_data)
        assert form.is_valid(
        ) is False, "Should be invalid with no username given"

    def test_empty_email_field(self):
        form_data = {
            'name': 'Foo',
        }
        form = LoginForm(data=form_data)
        assert form.is_valid(
        ) is False, "Should be invalid with no email given"

    def test_filled_form(self):
        form_data = {
            'name': 'Foo',
            'email': 'user@mail.com',
        }
        form = PasswordResetForm(data=form_data)
        assert form.is_valid(
        ) is True, "Should be valid if all fields are filled correctly"


class TestDeleteProfileForm:
    def test_empty_form(self):
        form_data = {}
        form = DeleteProfileForm(data=form_data)
        assert form.is_valid(
        ) is False, "Should be invalid if no data is given"

    def test_filled_form(self):
        form_data = {
            'confirmation_password': get_random_string(20),
        }
        form = DeleteProfileForm(data=form_data)
        assert form.is_valid(
        ) is True, "Should be valid if all fields are filled correctly"