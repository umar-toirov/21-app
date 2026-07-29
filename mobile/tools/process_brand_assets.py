"""Re-process brand assets: remove solid black/near-black backgrounds and crop."""
from PIL import Image
from pathlib import Path
from shutil import copyfile

brand = Path(r"C:\Users\Muhammadumar\OneDrive\Desktop\App\mobile\assets\brand")
src = Path(r"C:\Users\Muhammadumar\.cursor\projects\c-Users-Muhammadumar-OneDrive-Desktop-App\assets")

copies = {
    "logo_auth_src.png": "c__Users_Muhammadumar_AppData_Roaming_Cursor_User_workspaceStorage_8489dbcc9477b007e792a7d1ba4a31d6_images_For_website-ff90a466-4c0b-43cc-aff1-99307c4225a0.png",
    "icon_light_src.png": "c__Users_Muhammadumar_AppData_Roaming_Cursor_User_workspaceStorage_8489dbcc9477b007e792a7d1ba4a31d6_images_icon-bg-9b3991da-03b9-4977-9d56-2c92a36dac2a.png",
    "icon_dark_src.png": "c__Users_Muhammadumar_AppData_Roaming_Cursor_User_workspaceStorage_8489dbcc9477b007e792a7d1ba4a31d6_images_Inverted-bg-037f7d01-2669-45d4-a8d9-fdcb806a1fa3.png",
    "mountain_src.png": "c__Users_Muhammadumar_AppData_Roaming_Cursor_User_workspaceStorage_8489dbcc9477b007e792a7d1ba4a31d6_images_ChatGPT_Image_Jul_26__2026__02_48_54_PM-d4cdc05c-c968-47a7-bd36-6de256e2f791.png",
}
for dest, name in copies.items():
    copyfile(src / name, brand / dest)


def remove_bg_and_crop(
    path_in: Path, path_out: Path, thresh: int = 40, kill_white: bool = False
) -> None:
    im = Image.open(path_in).convert("RGBA")
    pixels = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if r <= thresh and g <= thresh and b <= thresh:
                pixels[x, y] = (0, 0, 0, 0)
            elif kill_white and r >= 250 and g >= 250 and b >= 250:
                pixels[x, y] = (0, 0, 0, 0)

    bbox = im.getbbox()
    if bbox:
        pad = 4
        l, t, r, b = bbox
        l = max(0, l - pad)
        t = max(0, t - pad)
        r = min(w, r + pad)
        b = min(h, b + pad)
        im = im.crop((l, t, r, b))
    im.save(path_out, optimize=True)
    print("saved", path_out.name, im.size)


remove_bg_and_crop(brand / "logo_auth_src.png", brand / "logo_auth.png", thresh=38, kill_white=False)
remove_bg_and_crop(brand / "icon_light_src.png", brand / "icon.png", thresh=38, kill_white=False)
remove_bg_and_crop(brand / "icon_dark_src.png", brand / "icon_gold.png", thresh=38, kill_white=False)
remove_bg_and_crop(brand / "mountain_src.png", brand / "mountain.png", thresh=30, kill_white=False)
copyfile(brand / "logo_auth.png", brand / "logo_full.png")
copyfile(brand / "icon.png", brand / "icon_on_blue.png")
print("done")
