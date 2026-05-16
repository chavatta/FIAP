from fastapi import FastAPI

app = FastAPI(title="analytics")


@app.get("/")
def read_root() -> dict[str, str]:
    return {"service": "analytics"}
