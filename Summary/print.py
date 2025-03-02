import os

def get_structure(startpath):
    """
    Raccoglie la struttura completa del progetto a partire da 'startpath',
    ignorando la cartella '.git'. Restituisce una stringa con l’elenco di
    tutte le directory e file.
    """
    lines = ["Struttura del progetto:"]
    for root, dirs, files in os.walk(startpath):
        if ".git" in dirs:
            dirs.remove(".git")
        level = root.replace(startpath, "").count(os.sep)
        indent = "    " * level
        lines.append(f"{indent}{os.path.basename(root)}/")
        for file in sorted(files):
            lines.append(f"{indent}    {file}")
    return "\n".join(lines)

def get_swift_files_content(startpath):
    """
    Cerca ricorsivamente tutti i file con estensione .swift a partire da 'startpath'
    (ignorando la cartella '.git') e raccoglie i loro contenuti.
    Restituisce una stringa che contiene, per ogni file, il percorso completo e il suo contenuto.
    """
    lines = ["\nContenuti dei file .swift:"]
    for root, dirs, files in os.walk(startpath):
        if ".git" in dirs:
            dirs.remove(".git")
        for file in sorted(files):
            if file.lower().endswith(".swift"):
                file_path = os.path.join(root, file)
                lines.append("\n" + "=" * 40)
                lines.append(f"File: {file_path}")
                lines.append("=" * 40)
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        lines.append(f.read())
                except Exception as e:
                    lines.append(f"Errore nell'apertura del file: {e}")
    return "\n".join(lines)

if __name__ == "__main__":
    current_dir = os.path.dirname(os.path.abspath(__file__))
    structure = get_structure(current_dir)
    swift_contents = get_swift_files_content(current_dir)
    output_text = structure + "\n" + swift_contents
    with open(os.path.join(current_dir, "output.txt"), "w", encoding="utf-8") as f:
        f.write(output_text)