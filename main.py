import streamlit as st
import os
import database as db 
import transcriber as ts 
import json

st.set_page_config(
    page_title="Video Archive Search",
    page_icon="icon.ico"
)

INDEX_FILE = ".indexed_folders.json"


def load_indexed_folders():
    if not os.path.exists(INDEX_FILE):
        return []

    with open(INDEX_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def save_indexed_folder(folder_path):
    folders = load_indexed_folders()

    if folder_path not in folders:
        folders.append(folder_path)

    with open(INDEX_FILE, "w", encoding="utf-8") as f:
        json.dump(folders, f, ensure_ascii=False, indent=4)

if "playing_video" not in st.session_state:
    st.session_state.playing_video = None
if "playing_time" not in st.session_state:
    st.session_state.playing_time = 0

st.title("Поиск по видеоархиву")

with st.sidebar:
    st.header("Панель управления")
    try:
        info = db.get_collection_info()
        st.metric(
            "Фрагментов в базе",
            info.points_count
        )
    except Exception:
        st.warning("База данных пока не создана")

    indexed_folders = load_indexed_folders()

    if indexed_folders:
        st.subheader("Проиндексированные папки")

        for folder in indexed_folders:
            st.caption(f"📁 {folder}")
    folder_path = st.text_input(
        "Путь к папке с видеоархивом",
        placeholder="Например: C:/Users/User/Videos",
        help="Скопируйте путь к папке"
    )

    if st.button("Начать сканирование"):
        if not folder_path:
            st.error("Пожалуйста, укажите путь к папке")
        elif not os.path.exists(folder_path):
            st.error("Указанный путь не существует")
        else:
            supported_exts = (".mp4", ".mkv", ".mov", ".avi")
            video_files = []
            for root, dirs, files in os.walk(folder_path):
                for file in files:
                    if file.lower().endswith(supported_exts):
                        full_path = os.path.join(root, file)
                        video_files.append(full_path)
            
            if not video_files:
                st.warning("Видеофайлы не найдены")
            else:
                st.info(f"Найдено {len(video_files)} видеофайлов")

                progress_bar = st.progress(0)
                status_message = st.empty()

                for idx, path in enumerate(video_files):
                    if db.is_video_in_db(path):
                        continue
                    file_name = os.path.basename(path)
                    relative_dir = os.path.relpath(os.path.dirname(path), folder_path)
                    display_folder = f" [Папка: {relative_dir}]" if relative_dir != "." else ""

                    status_message = st.markdown(
                        f"**Обработка ({idx+1}/{len(video_files)}):** `{file_name}`{display_folder}"
                    )

                    try:
                        chunks = ts.transcribe_video(path)
                        db.add_chunks_to_db(path, chunks)
                    except Exception as e:
                        st.error(f"Ошибка при обработке файла {file_name}: {e}")

                    progress_bar.progress((idx + 1) / len(video_files))
                
                save_indexed_folder(folder_path)

                status_message.success(
                    f"Папка успешно проиндексирована:\n{folder_path}"
                )

search_query = st.text_input(
    "Что вы хотите найти в видеоархиве?", 
    placeholder="Например: Коля ест сахар..."
)

if search_query:
    hits = db.search_context(search_query, limit=5)

    if not hits:
        st.warning("По вашему запросу ничего не найдено")
    else:
        st.subheader("Результаты поиска")

        for index, hit in enumerate(hits):
            payload = hit.payload

            start_sec = int(payload["start_time"])
            button_label = (
                f"{payload['video_name']}\n\n"
                f"» {payload['text_content']}"
            )

            if st.button(button_label, key=f"btn_{hit.id}", use_container_width=True):
                st.session_state.playing_video = payload["video_path"]
                st.session_state.playing_time = start_sec
                st.rerun()
        

        st.title("Видеоплеер")

        if st.session_state.playing_video and st.session_state.playing_time is not None:
            current_file = os.path.basename(st.session_state.playing_video)
            st.text(f"Файл: {current_file}")

            if st.session_state.playing_time == 0:
                st.video(st.session_state.playing_video)
            else:
                st.video(
                    st.session_state.playing_video,
                    start_time=st.session_state.playing_time
                )
        else:
            st.info("Выберите любой фрагмент видео слева")
