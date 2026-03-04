async function loadBenchmarkChart() {
  const root = document.getElementById("bar-chart");
  if (!root) return;

  let data;
  try {
    const res = await fetch("data/benchmarks.json");
    data = await res.json();
  } catch (err) {
    root.textContent = "Failed to load chart data.";
    return;
  }

  const maxScore = Math.max(...data.map((d) => d.score), 1);

  data.forEach((item, idx) => {
    const row = document.createElement("div");
    row.className = "bar-row";

    const label = document.createElement("div");
    label.className = "bar-label";
    label.textContent = item.name;

    const track = document.createElement("div");
    track.className = "bar-track";
    const fill = document.createElement("div");
    fill.className = "bar-fill";
    track.appendChild(fill);

    const value = document.createElement("div");
    value.className = "bar-value";
    value.textContent = item.score.toFixed(1);

    row.append(label, track, value);
    root.appendChild(row);

    const widthPercent = (item.score / maxScore) * 100;
    setTimeout(() => {
      fill.style.width = widthPercent.toFixed(2) + "%";
    }, 120 + idx * 90);
  });
}

loadBenchmarkChart();
