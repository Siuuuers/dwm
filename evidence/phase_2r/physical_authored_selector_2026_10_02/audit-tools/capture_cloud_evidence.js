// Execute in functions.exec via new Function("tools", "text", "config", source).
// config: {runId, root, repository?:"Siuuuers/dwm", omissions?:{artifactId:reason}, cachedArtifacts?:Array<downloadRecord>}
// Downloads only. Never executes Godot/PowerShell or mutates GitHub.
return (async () => {
  const repo = config.repository || "Siuuuers/dwm";
  if (!Number.isSafeInteger(config.runId) || config.runId <= 0) throw Error("Valid runId required");
  if (!/^\/workspace\/scratch\/b58854ff0f39\/[A-Za-z0-9_./-]+$/.test(config.root) || config.root.split("/").includes("..")) throw Error("Safe task-local root required");
  const root = config.root.replace(/\/$/, "");
  const helper = "/workspace/scratch/b58854ff0f39/capture_cloud_evidence.py";
  const quote = s => "'" + s.replaceAll("'", "'\"'\"'") + "'";
  function check(result) { if (result.isError) throw Error("GitHub connector reported an error"); return result; }
  function data(result) {
    check(result);
    for (const c of [result.structuredContent, result.structuredContent?.structuredContent, result]) {
      if (!c) continue;
      if (typeof c.content === "string") { try { return JSON.parse(c.content); } catch {} }
      if (Array.isArray(c.jobs) || Array.isArray(c.artifacts) || typeof c.id === "number") return c;
    }
    throw Error("Unexpected GitHub JSON result envelope");
  }
  function base64(s) {
    const binary = encodeURIComponent(s).replace(/%([0-9A-F]{2})/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", out = [];
    for (let i = 0; i < binary.length; i += 3) {
      const a = binary.charCodeAt(i), b = binary.charCodeAt(i + 1), c = binary.charCodeAt(i + 2);
      out.push(alphabet[a >> 2], alphabet[((a & 3) << 4) | (Number.isNaN(b) ? 0 : b >> 4)],
        Number.isNaN(b) ? "=" : alphabet[((b & 15) << 2) | (Number.isNaN(c) ? 0 : c >> 6)], Number.isNaN(c) ? "=" : alphabet[c & 63]);
    }
    return out.join("");
  }
  async function saveText(path, value) {
    await tools.apply_patch("*** Begin Patch\n*** Add File: " + path + ".b64\n+" + base64(value) + "\n*** End Patch");
    const decoded = await tools.exec_command({cmd: "python " + quote(helper) + " decode-text " + quote(path + ".b64"), max_output_tokens: 200});
    if (decoded.exit_code !== 0) throw Error("Evidence materialization failed: " + path + ": " + decoded.output);
  }
  async function saveJson(name, value) { await saveText(root + "/" + name, JSON.stringify(value, null, 2) + "\n"); }
  async function get(url) { return data(await tools.mcp__codex_apps__github_fetch({url})); }
  async function collection(endpoint, key) {
    const all = [];
    let total = null;
    for (let page = 1; page <= 100; page++) {
      const body = await get(endpoint + (endpoint.includes("?") ? "&" : "?") + "per_page=100&page=" + page);
      if (!Array.isArray(body[key]) || !Number.isInteger(body.total_count)) throw Error("Collection shape mismatch");
      if (total !== null && total !== body.total_count) throw Error("Collection changed during capture");
      total = body.total_count; all.push(...body[key]);
      if (all.length === total) return {total_count: total, [key]: all};
      if (all.length > total || body[key].length === 0) throw Error("Incomplete or unstable pagination");
    }
    throw Error("Collection pagination limit exceeded");
  }
  const api = "https://api.github.com/repos/" + repo + "/actions/runs/" + config.runId;
  const results = await Promise.allSettled([get(api), collection(api + "/jobs?filter=all", "jobs"), collection(api + "/artifacts", "artifacts")]);
  for (const result of results) if (result.status !== "fulfilled") throw result.reason;
  const [run, jobs, artifacts] = results.map(x => x.value);
  if (run.id !== config.runId || run.status !== "completed") throw Error("Completed exact run required before capture");
  await saveJson("run.json", run);
  await saveJson("jobs.json", jobs);
  await saveJson("artifacts-api.json", artifacts);
  const omissions = config.omissions || {};
  await saveJson("omissions.json", omissions);
  for (let i = 0; i < jobs.jobs.length; i += 3) {
    const batch = jobs.jobs.slice(i, i + 3);
    const logs = await Promise.allSettled(batch.map(job => tools.mcp__codex_apps__github_fetch_workflow_job_logs({repo_full_name: repo, job_id: job.id})));
    for (let n = 0; n < logs.length; n++) {
      if (logs[n].status !== "fulfilled") throw logs[n].reason;
      const result = check(logs[n].value), content = result.structuredContent?.content;
      if (typeof content !== "string") throw Error("Missing decoded job log for " + batch[n].id);
      await saveText(root + "/logs/" + batch[n].id + ".log", content);
    }
  }
  const manifest = [];
  for (const artifact of artifacts.artifacts) {
    if (Object.hasOwn(omissions, String(artifact.id))) {
      if (typeof omissions[artifact.id] !== "string" || !omissions[artifact.id].trim()) throw Error("Omission needs a reason");
      continue;
    }
    if (artifact.expired) throw Error("Artifact expired: " + artifact.id);
    const cached = (config.cachedArtifacts || []).find(x => x.id === artifact.id);
    if (cached) {
      if (!["name", "digest", "size_in_bytes"].every(k => cached[k] === artifact[k]) ||
          cached.workflow_run?.id !== run.id || cached.workflow_run?.head_sha !== run.head_sha ||
          typeof cached.local_zip !== "string") throw Error("Cached artifact metadata changed");
      manifest.push(cached);
      continue; // verify-extract below still hashes the original ZIP and every member.
    }
    const result = check(await tools.mcp__codex_apps__github_download_workflow_artifact({repo_full_name: repo, artifact_id: artifact.id, file_name: artifact.name + ".zip"}));
    const file = result.structuredContent?.file_uri;
    if (!file?.file_id) throw Error("Artifact tool returned no reusable file ID");
    // Use the opaque file ID. Never persist or print the temporary signed URL.
    const local = await tools.download_file({file_id: file.file_id});
    if (typeof local.path !== "string") throw Error("Download tool returned no local path");
    manifest.push({id: artifact.id, name: artifact.name, digest: artifact.digest, size_in_bytes: artifact.size_in_bytes, workflow_run: artifact.workflow_run, local_zip: local.path});
    text({downloaded_artifact: artifact.name, bytes: local.size_bytes});
  }
  await saveJson("artifact-manifest.json", manifest);
  const extracted = await tools.exec_command({cmd: "python " + quote(helper) + " verify-extract " + quote(root), max_output_tokens: 3000, yield_time_ms: 10000});
  if (extracted.exit_code !== 0) throw Error("Artifact verification failed: " + extracted.output);
  text({captured_run: run.run_number, run_id: run.id, head_sha: run.head_sha, jobs: jobs.jobs.length, artifacts: manifest.length, root});
  return {run, jobs, artifacts, manifest};
})();
