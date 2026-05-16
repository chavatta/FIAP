from fastapi import FastAPI

app = FastAPI(title="flag")


@app.get("/")
def read_root() -> dict[str, str]:
    return {"service": "flag"}
