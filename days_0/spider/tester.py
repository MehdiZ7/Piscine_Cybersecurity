from spider import extract_images, is_image_url

HTML = """<html><body>
<img src="a.png">
<img src="../img/b.JPG?x=1">
<img src="notes.txt">
<img src="https://cdn.example.com/c.gif">
<img src="a.png">
<img src="lazy.webp">
<img src="photo.jpeg#top">
</body></html>"""

print(extract_images(HTML))
