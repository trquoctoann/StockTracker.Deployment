import asyncio

from app.archive.raw_archive import RawArchive
from app.control.store import PipelineStore
from app.core.config import Settings
from app.core.exceptions import PipelineBusyError
from app.engine.pipeline import PipelineEngine


async def main() -> None:
    settings = Settings()
    store = PipelineStore(settings.control_database_url)
    await store.connect()
    archive = RawArchive(settings, store=store)
    await archive.ensure_bucket()

    async with store.acquire_pipeline_lock("e2e_lock"):
        try:
            async with store.acquire_pipeline_lock("e2e_lock"):
                raise AssertionError("duplicate advisory lock was acquired")
        except PipelineBusyError:
            pass

    captured = {}

    async def work() -> None:
        async with PipelineEngine.step("probe:FPT") as should_run:
            assert should_run
            captured["raw"] = await archive.capture(
                "e2e_probe",
                [{"symbol": "FPT", "close": 123.5}],
                source="test",
            )
            await PipelineEngine.put_watermark(
                "probe",
                "FPT",
                {"state": "data", "count": 1},
                source="test",
            )

    PipelineEngine.configure(store, heartbeat_seconds=5)
    run_id = await PipelineEngine.run("e2e_data_foundation", work, trigger="e2e")
    run = await store.get_run(run_id)
    watermark = await store.get_watermark("e2e_data_foundation", "probe", "FPT")
    raw = captured["raw"]
    replay = await archive.load(raw.key, expected_checksum=raw.checksum_sha256)

    assert run and run.status == "completed"
    assert watermark and watermark.cursor["count"] == 1
    assert replay.payload == [{"symbol": "FPT", "close": 123.5}]
    await store.close()
    print(f"E2E_OK run={run_id} raw={raw.key}")


asyncio.run(main())
