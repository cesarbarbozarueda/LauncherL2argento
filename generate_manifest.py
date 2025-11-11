import os, hashlib, json

# === CONFIGURACIÓN ===
# Carpeta donde están los archivos del patch (puede ser "System" o el root del juego)
BASE_DIR = "."
# URL base del repositorio con "raw", adaptada a tu caso:
RAW_BASE_URL = "https://github.com/cesarbarbozarueda/LauncherL2argento.git"
# Nombre de salida del JSON:
OUTPUT_FILE = "update.json"


def sha1_of_file(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest().upper()


def build_manifest(base_dir):
    files = []
    for root, _, filenames in os.walk(base_dir):
        for filename in filenames:
            if filename == OUTPUT_FILE:
                continue
            full_path = os.path.join(root, filename)
            rel_path = os.path.relpath(full_path, base_dir).replace("\\", "/")
            sha1 = sha1_of_file(full_path)
            url = RAW_BASE_URL + rel_path
            files.append({
                "path": rel_path,
                "sha1": sha1,
                "url": url
            })
    return {"version": "1.0.0", "files": files}


def main():
    manifest = build_manifest(BASE_DIR)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    print(f"✅ Manifest generado con {len(manifest['files'])} archivos en {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
