import os
import hashlib
from uuid import UUID
import streamlit as st
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct, Filter, FieldCondition, MatchValue
from sentence_transformers import SentenceTransformer

DB_PATH = os.path.join(os.path.dirname(__file__), ".qdrant_db")
COLLECTION_NAME = "video_archive"

@st.cache_resource
def init_resources():
    qdrant_client = QdrantClient(path=DB_PATH)
    embedding_encoder = SentenceTransformer("intfloat/multilingual-e5-small", device="cpu")
    
    if not qdrant_client.collection_exists(COLLECTION_NAME):
        qdrant_client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(
                size=384,
                distance=Distance.COSINE
            )
        )
    return qdrant_client, embedding_encoder

client, encoder = init_resources()

def generate_id(video_path: str, start_time: float) -> str:
    unique_str = f"{video_path}_{start_time:.2f}"
    hash_hex = hashlib.md5(unique_str.encode("utf-8")).hexdigest()
    return str(UUID(hash_hex))

def add_chunks_to_db(video_path: str, chunks: list):
    points = []

    for idx, chunk in enumerate(chunks):
        text = chunk["text"].strip()
        if not text:
            continue

        prepared_text = f"passage: {text}"
        vector = encoder.encode(prepared_text).tolist()
        point_id = generate_id(video_path, chunk["start"])
        points.append(
            PointStruct(
                id=point_id,
                vector=vector,
                payload={
                    "video_path": video_path,
                    "video_name": os.path.basename(video_path),
                    "start_time": chunk["start"],
                    "end_time": chunk["end"],
                    "text_content": text
                }
            )
        )

    if points:
        client.upsert(collection_name=COLLECTION_NAME, points=points)

def is_video_in_db(video_path: str) -> bool:

    result = client.scroll(
        collection_name=COLLECTION_NAME,
        scroll_filter=Filter(
            must=[
                FieldCondition(
                    key="video_path",
                    match=MatchValue(value=video_path)
                )
            ]
        ),
        limit=1
    )

    return len(result[0]) > 0

def search_context(query_text: str, limit: int = 5):
    if not query_text.strip():
        return []

    prepared_query = f"query: {query_text}"
    query_vector = encoder.encode(prepared_query).tolist()

    search_results = client.query_points(
        collection_name=COLLECTION_NAME, 
        query=query_vector,
        limit=limit
    )

    return search_results.points

def get_collection_info():
    return client.get_collection(COLLECTION_NAME)