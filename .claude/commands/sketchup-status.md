Show the current status of all furniture projects and the SketchUp bridge.

## Steps

1. **Check bridge health.** Run:
   ```
   curl -s http://127.0.0.1:7654/status
   ```
   Report: connected / not connected. If not connected, note that SketchUp may be closed or the extension not loaded.

2. **List all projects.** Find every `projects/*/state.json` file. For each, read and extract:
   - Project name and ID
   - Overall dimensions (W × D × H)
   - Number of parts
   - Materials used
   - Last modified timestamp of state.json

3. **Display as a table:**
   ```
   ID                    Name                    Dimensions           Parts  Materials
   acceptance-bench      Entry Bench             72"W × 18"D × 30"H  14     white_oak
   bookshelf-001         Bookshelf               36"W × 12"D × 72"H   9     white_oak, birch_plywood
   media-console-001     Mid-Century Console     60"W × 20"D × 26"H  13     walnut, birch_plywood
   ```

4. **Show a perspective render for each project.** Read `projects/{id}/renders/perspective.png` for every project that has one.

5. **Summarize** the scene: total number of projects, bridge status, and any projects missing renders or state files.
