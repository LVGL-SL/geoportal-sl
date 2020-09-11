# Generated by Django 2.1.3 on 2020-08-31 09:41

from django.db import migrations, models
import django.utils.timezone


class Migration(migrations.Migration):

    dependencies = [
        ('useroperations', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='InspireDownloads',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('user_id', models.IntegerField()),
                ('user_email', models.EmailField(max_length=255)),
                ('service_name', models.CharField(max_length=250)),
                ('no_of_tiles', models.IntegerField()),
                ('date', models.DateTimeField(default=django.utils.timezone.now)),
            ],
        ),
    ]
