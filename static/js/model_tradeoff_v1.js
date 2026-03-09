function renderModelTradeoffV1() {
  const mapRoot = document.getElementById("model-tradeoff-map");
  const spreadRoot = document.getElementById("model-accuracy-spread");
  if (!mapRoot || !spreadRoot || typeof Plotly === "undefined") return;

  fetch("static/data/model_tradeoff_v1.json")
    .then((r) => r.json())
    .then((payload) => {
      const preferredOrder = [
        "gemini-2.0-flash-lite",
        "gemini-2.5-flash-lite",
        "gemini-2.5-flash",
        "gpt-4o-mini",
        "gpt-5-nano",
        "gpt-5-mini",
      ];
      const rank = new Map(preferredOrder.map((m, i) => [m, i]));
      const models = (payload.models || []).slice().sort((a, b) => {
        const ai = rank.has(a.model) ? rank.get(a.model) : 999;
        const bi = rank.has(b.model) ? rank.get(b.model) : 999;
        if (ai !== bi) return ai - bi;
        return String(a.model).localeCompare(String(b.model));
      });
      if (!models.length) {
        mapRoot.textContent = "No tradeoff data available.";
        spreadRoot.textContent = "No spread data available.";
        return;
      }

      const colorByModel = {};
      const gptPalette = ["#1f4f99", "#2f6fca", "#5d8fe0", "#86acef"];
      const geminiPalette = ["#a35400", "#c06a00", "#d9831f", "#f2a64b"];
      const otherPalette = ["#4b5563", "#6b7280", "#9ca3af"];

      function family(model) {
        const m = (model || "").toLowerCase();
        if (m.includes("gemini")) return "gemini";
        if (m.includes("gpt")) return "gpt";
        return "other";
      }

      const byFamily = { gpt: [], gemini: [], other: [] };
      models.forEach((m) => {
        byFamily[family(m.model)].push(m.model);
      });
      Object.keys(byFamily).forEach((k) => byFamily[k].sort());

      byFamily.gpt.forEach((model, i) => {
        colorByModel[model] = gptPalette[i % gptPalette.length];
      });
      byFamily.gemini.forEach((model, i) => {
        colorByModel[model] = geminiPalette[i % geminiPalette.length];
      });
      byFamily.other.forEach((model, i) => {
        colorByModel[model] = otherPalette[i % otherPalette.length];
      });

      const x = models.map((m) => m.duration_per_task_median);
      const y = models.map((m) => m.cost_per_task_median);
      const acc = models.map((m) => m.accuracy_pct);
      const spread = models.map((m) => m.accuracy_spread);
      const names = models.map((m) => m.model);
      const colors = models.map((m) => colorByModel[m.model]);
      const sizes = spread.map((s) => 16 + s * 0.24);
      const xMin = Math.min(...x);
      const xMax = Math.max(...x);
      const yMin = Math.min(...y);
      const yMax = Math.max(...y);
      const xPad = (xMax - xMin || 1) * 0.08;
      const yPad = (yMax - yMin || 1) * 0.12;

      const textPositions = names.map((name) =>
        name === "gpt-5-nano" ? "middle left" : "middle right"
      );

      const mapTrace = {
        type: "scatter",
        mode: "markers+text",
        x: x,
        y: y,
        text: names,
        textposition: textPositions,
        marker: {
          size: sizes,
          color: colors,
          opacity: 0.85,
          line: { color: "#ffffff", width: 1.5 },
        },
        customdata: models.map((m) => [
          m.model,
          m.accuracy_pct,
          m.accuracy_spread,
          m.accuracy_pct_min,
          m.accuracy_pct_max,
        ]),
        hovertemplate:
          "<b>%{customdata[0]}</b><br>" +
          "Duration: %{x:.2f} s/task<br>" +
          "Cost: $%{y:.4f} /task<br>" +
          "Accuracy: %{customdata[1]:.1f}%<br>" +
          "Instability (accuracy swing): %{customdata[2]:.1f}%<extra></extra>",
      };

      const mapLayout = {
        title: {
          text: "Model Cost vs Speed",
          font: { family: "Inter, sans-serif", size: 30, color: "#0f172a" },
        },
        paper_bgcolor: "white",
        plot_bgcolor: "white",
        margin: { l: 88, r: 32, t: 56, b: 55 },
        xaxis: {
          title: "Median duration per task (s)",
          range: [xMin - xPad, xMax + xPad],
          fixedrange: true,
          gridcolor: "rgba(148, 163, 184, 0.2)",
        },
        yaxis: {
          title: "Median cost per task ($)",
          range: [Math.max(0, yMin - yPad), yMax + yPad],
          fixedrange: true,
          tickformat: ".4f",
          gridcolor: "rgba(148, 163, 184, 0.2)",
        },
        hoverlabel: {
          bgcolor: "rgba(17, 24, 39, 0.94)",
          bordercolor: "#0f172a",
          font: { color: "#f8fafc", size: 12 },
          align: "left",
        },
        showlegend: false,
      };

      Plotly.newPlot(mapRoot, [mapTrace], mapLayout, {
        responsive: true,
        displayModeBar: false,
        scrollZoom: false,
      });

      const spreadTrace = {
        type: "bar",
        x: names,
        y: acc,
        marker: {
          color: colors,
          opacity: 0.88,
          line: { color: "#ffffff", width: 1.2 },
        },
        error_y: {
          type: "data",
          symmetric: false,
          array: models.map((m) => m.accuracy_pct_max - m.accuracy_pct),
          arrayminus: models.map((m) => m.accuracy_pct - m.accuracy_pct_min),
          visible: true,
          color: "rgba(55, 65, 81, 0.9)",
          thickness: 1.4,
          width: 4,
        },
        customdata: models.map((m) => [
          m.accuracy_pct_min,
          m.accuracy_pct_max,
          m.accuracy_spread,
        ]),
        hovertemplate:
          "<b>%{x}</b><br>" +
          "Accuracy: %{y:.1f}%<br>" +
          "Instability (accuracy swing): %{customdata[2]:.1f}%<extra></extra>",
      };

      const spreadLayout = {
        title: {
          text: "Model Accuracy and Stability",
          font: { family: "Inter, sans-serif", size: 30, color: "#0f172a" },
        },
        paper_bgcolor: "white",
        plot_bgcolor: "white",
        margin: { l: 68, r: 20, t: 56, b: 55 },
        yaxis: {
          title: "Aggregated accuracy (%)",
          range: [0, 105],
          fixedrange: true,
          gridcolor: "rgba(148, 163, 184, 0.2)",
        },
        xaxis: { title: "Model (LLM)", fixedrange: true },
        hoverlabel: {
          bgcolor: "rgba(17, 24, 39, 0.94)",
          bordercolor: "#0f172a",
          font: { color: "#f8fafc", size: 12 },
          align: "left",
        },
        showlegend: false,
      };

      Plotly.newPlot(spreadRoot, [spreadTrace], spreadLayout, {
        responsive: true,
        displayModeBar: false,
        scrollZoom: false,
      });
    })
    .catch(() => {
      mapRoot.textContent = "Failed to load interactive tradeoff data.";
      spreadRoot.textContent = "Failed to load interactive tradeoff data.";
    });
}

document.addEventListener("DOMContentLoaded", renderModelTradeoffV1);
