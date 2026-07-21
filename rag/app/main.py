from fastapi import FastAPI, UploadFile, File
from pydantic import BaseModel
from langchain_ollama import OllamaEmbeddings
from langchain_chroma import Chroma
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.document_loaders import PyPDFLoader
from dotenv import load_dotenv
import httpx
import ollama
import asyncio
from concurrent.futures import ThreadPoolExecutor
import tempfile
import os
from fastapi import Request

load_dotenv()

app = FastAPI(title="RAG API")

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://172.18.0.1:11434")
MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:3b")
EMBED_MODEL = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")

executor = ThreadPoolExecutor()
_ollama_client = None
vectorstore = None

def get_ollama_client():
    global _ollama_client
    if _ollama_client is None:
        _ollama_client = ollama.Client(
            host=OLLAMA_URL,
            timeout=httpx.Timeout(connect=10.0, read=120.0, write=120.0, pool=5.0)
        )
    return _ollama_client

def get_embeddings():
    return OllamaEmbeddings(
        model=EMBED_MODEL,
        base_url=OLLAMA_URL,
    )

def get_vectorstore():
    global vectorstore
    if vectorstore is None:
        vectorstore = Chroma(
            embedding_function=get_embeddings(),
            persist_directory="./chroma_data"
        )
    return vectorstore

class QueryRequest(BaseModel):
    question: str

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/query-direct")
async def query_direct(req: QueryRequest):
    client = get_ollama_client()
    loop = asyncio.get_event_loop()
    response = await loop.run_in_executor(
        executor,
        lambda: client.generate(model=MODEL, prompt=req.question)
    )
    return {"answer": response.response}

@app.post("/ingest")
async def ingest(file: UploadFile = File(...)):
    vs = get_vectorstore()
    with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name
    loader = PyPDFLoader(tmp_path)
    docs = loader.load()
    splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
    chunks = splitter.split_documents(docs)
    vs.add_documents(chunks)
    os.unlink(tmp_path)
    return {"ingested": len(chunks)}

@app.post("/query")
async def query(req: QueryRequest):
    vs = get_vectorstore()
    loop = asyncio.get_event_loop()
    docs = await loop.run_in_executor(
        executor,
        lambda: vs.similarity_search(req.question, k=3)
    )
    context = "\n".join([d.page_content for d in docs])
    prompt = f"Context:\n{context}\n\nQuestion: {req.question}\n\nAnswer:"
    response = await loop.run_in_executor(
        executor,
        lambda: get_ollama_client().generate(model=MODEL, prompt=prompt)
    )
    return {"answer": response.response, "sources": len(docs)}
