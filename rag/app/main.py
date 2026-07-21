from fastapi import FastAPI, UploadFile, File
from pydantic import BaseModel
from langchain_ollama import OllamaLLM
from langchain_chroma import Chroma
from langchain_ollama import OllamaEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.document_loaders import PyPDFLoader
import tempfile
import os

app = FastAPI(title="RAG API")

# Fedora docker net 
# OLLAMA_URL = os.getenv("OLLAMA_URL", "http://172.21.0.1:11434")

# Nobara docker net 
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://172.18.0.1:11434")

MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:3b")
EMBED_MODEL = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")

llm = OllamaLLM(model=MODEL, base_url=OLLAMA_URL)
embeddings = OllamaEmbeddings(model=EMBED_MODEL, base_url=OLLAMA_URL)
vectorstore = None

def get_vectorstore():
    global vectorstore
    if vectorstore is None:
        vectorstore = Chroma(embedding_function=embeddings, persist_directory="./chroma_data")
    return vectorstore

class QueryRequest(BaseModel):
    question: str

@app.get("/health")
def health():
    return {"status": "ok"}

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
    vectorstore.add_documents(chunks)
    os.unlink(tmp_path)
    return {"ingested": len(chunks)}

@app.post("/query")
def query(req: QueryRequest):
    vs = get_vectorstore()
    docs = vectorstore.similarity_search(req.question, k=3)
    context = "\n".join([d.page_content for d in docs])
    prompt = f"Context:\n{context}\n\nQuestion: {req.question}\n\nAnswer:"
    response = llm.invoke(prompt)
    return {"answer": response, "sources": len(docs)}
