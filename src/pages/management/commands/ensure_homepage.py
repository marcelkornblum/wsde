from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Ensure a HomePage and default Wagtail Site exist, creating them if needed."

    def handle(self, *args, **options):
        from wagtail.models import Page, Site

        from pages.models import HomePage

        root = Page.objects.filter(depth=1).first()
        if root is None:
            self.stderr.write("❌  No root page found. Run migrations first.")
            return

        if HomePage.objects.exists():
            home = HomePage.objects.first()
            self.stdout.write("✅  HomePage already exists.")
        else:
            # Wagtail's initial migration creates a plain Page with slug "home".
            # Delete it so we can take its place cleanly.
            default_page = Page.objects.filter(depth=2, slug="home").first()
            if default_page is not None:
                Site.objects.filter(root_page=default_page).update(root_page=root)
                default_page.delete()

            home = HomePage(title="Home", slug="home", live=True)
            root.add_child(instance=home)
            self.stdout.write(f"✅  Created HomePage (pk={home.pk}).")

        # Ensure a default Site exists pointing at the HomePage
        site = Site.objects.filter(is_default_site=True).first()
        if site is None:
            Site.objects.create(
                hostname="localhost",
                port=80,
                root_page=home,
                is_default_site=True,
                site_name="Worst Stag Do Ever",
            )
            self.stdout.write("✅  Created default Site pointing at HomePage.")
        elif site.root_page_id != home.pk:
            site.root_page = home
            site.save()
            self.stdout.write("✅  Updated default Site to point at HomePage.")
        else:
            self.stdout.write("✅  Default Site already configured correctly.")
