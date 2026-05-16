from fastapi import FastAPI

app = FastAPI(title="targeting")


@app.get("/")
def read_root() -> dict[str, str]:
    return {"service": "targeting"}
