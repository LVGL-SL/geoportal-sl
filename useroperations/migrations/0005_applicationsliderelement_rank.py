# Generated by Django 2.2.17 on 2021-02-02 14:36

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('useroperations', '0004_landingpagedispatch'),
    ]

    operations = [
        migrations.AddField(
            model_name='applicationsliderelement',
            name='rank',
            field=models.IntegerField(default=1000),
            preserve_default=False,
        ),
    ]
