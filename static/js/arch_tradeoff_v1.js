function renderArchTradeoffV1() {
  const trendRoot = document.getElementById("arch-tradeoff-trend");
  const accRoot = document.getElementById("arch-accuracy-panel");
  if (!trendRoot || !accRoot || typeof Plotly === "undefined") return;

  fetch("static/data/arch_tradeoff_v1.json")
    .then((r) => r.json())
    .then((payload) => {
      const points = payload.points || [];
      const archOrder = payload.arch_order || ["P&E", "crag", "lats"];
      const archLabels = payload.arch_labels || { "P&E": "Plan-and-Execute", crag: "CRAG", lats: "LATS" };
      const modelOrder = payload.model_order || [];
      const archSummary = payload.arch_summary || [];

      if (!points.length) {
        trendRoot.textContent = "No architecture tradeoff data available.";
        accRoot.textContent = "No architecture accuracy data available.";
        return;
      }

      // Match reference plot color coding:
      // lats = blue, crag = red, P&E = green
      const colorByArch = {
        lats: "#4e79a7",
        crag: "#e15759",
        "P&E": "#76b041",
      };

      const rank = new Map(modelOrder.map((m, i) => [m, i]));
      const orderedPointsByArch = new Map();
      const pointXs = points.map((p) => p.latency);
      const pointYs = points.map((p) => p.cost);
      const pointXMin = Math.min(...pointXs);
      const pointXMax = Math.max(...pointXs);
      const pointYMin = Math.min(...pointYs);
      const pointYMax = Math.max(...pointYs);
      const pointXSpan = pointXMax - pointXMin || 1;
      const pointYSpan = pointYMax - pointYMin || 1;
      const trendXMin = Math.max(0, pointXMin - pointXSpan * 0.15);
      const trendXMax = pointXMax + pointXSpan * 0.15;
      const trendYMin = Math.max(0, pointYMin - pointYSpan * 0.15);
      const trendYMax = pointYMax + pointYSpan * 0.15;
      const traces = archOrder
        .filter((arch) => points.some((p) => p.arch === arch))
        .map((arch) => {
          const pts = points
            .filter((p) => p.arch === arch)
            .slice()
            .sort((a, b) => {
              const ai = rank.has(a.model) ? rank.get(a.model) : 999;
              const bi = rank.has(b.model) ? rank.get(b.model) : 999;
              if (ai !== bi) return ai - bi;
              return String(a.model).localeCompare(String(b.model));
            });
          orderedPointsByArch.set(arch, pts);
          return {
            type: "scatter",
            mode: "markers",
            name: archLabels[arch] || arch,
            x: pts.map((p) => p.latency),
            y: pts.map((p) => p.cost),
            marker: {
              size: 10,
              color: colorByArch[arch] || "#666",
              line: { color: "#fff", width: 1.2 },
            },
            customdata: pts.map((p) => [p.model, p.accuracy]),
            hovertemplate:
              "<b>" + (archLabels[arch] || arch) + "</b><br>" +
              "Model: %{customdata[0]}<br>" +
              "Duration: %{x:.2f} s/task<br>" +
              "Cost: $%{y:.4f} /task<br>" +
              "Accuracy: %{customdata[1]:.1f}%<extra></extra>",
          };
        });

      const trendArrows = [];
      const trendDeltaLabels = [];
      const formatPct = (v) => (v >= 0 ? "+" : "") + v.toFixed(1) + "%";
      const labelOffsetByArch = {
        lats: { x: 18, y: 16 },
        crag: { x: 18, y: -14 },
        "P&E": { x: 18, y: 24 },
      };
      for (const arch of archOrder) {
        const pts = orderedPointsByArch.get(arch) || [];
        if (pts.length < 2) continue;

        const pairwiseCostDeltas = [];
        const pairwiseLatencyDeltas = [];
        for (let i = 0; i < pts.length; i += 1) {
          for (let j = i + 1; j < pts.length; j += 1) {
            const a = pts[i];
            const b = pts[j];
            if (a.cost > 0) pairwiseCostDeltas.push(((b.cost - a.cost) / a.cost) * 100);
            if (a.latency > 0) pairwiseLatencyDeltas.push(((b.latency - a.latency) / a.latency) * 100);
          }
        }
        const avg = (arr) => (arr.length ? arr.reduce((s, v) => s + v, 0) / arr.length : 0);
        const costDelta = avg(pairwiseCostDeltas);
        const latencyDelta = avg(pairwiseLatencyDeltas);
        const avgLatency = pts.reduce((s, p) => s + p.latency, 0) / pts.length;
        const avgCost = pts.reduce((s, p) => s + p.cost, 0) / pts.length;
        const rawTargetLatency = Math.max(0, avgLatency * (1 + latencyDelta / 100));
        const rawTargetCost = Math.max(0, avgCost * (1 + costDelta / 100));
        const targetLatency = Math.min(trendXMax, Math.max(trendXMin, rawTargetLatency));
        const targetCost = Math.min(trendYMax, Math.max(trendYMin, rawTargetCost));
        if (avgLatency !== targetLatency || avgCost !== targetCost) {
          trendArrows.push({
            x: targetLatency,
            y: targetCost,
            ax: avgLatency,
            ay: avgCost,
            xref: "x",
            yref: "y",
            axref: "x",
            ayref: "y",
            text: "",
            showarrow: true,
            arrowhead: 3,
            arrowsize: 1.2,
            arrowwidth: 2,
            arrowcolor: colorByArch[arch] || "#666",
            opacity: 0.9,
          });
        }
        const offset = labelOffsetByArch[arch] || { x: 18, y: 14 };
        trendDeltaLabels.push({
          x: (avgLatency + targetLatency) / 2,
          y: (avgCost + targetCost) / 2,
          xref: "x",
          yref: "y",
          text: "ΔCost " + formatPct(costDelta) + "<br>ΔDuration " + formatPct(latencyDelta),
          showarrow: false,
          xanchor: "left",
          yanchor: "bottom",
          xshift: offset.x,
          yshift: offset.y,
          bgcolor: "rgba(255,255,255,0.86)",
          bordercolor: "rgba(148,163,184,0.52)",
          borderwidth: 1,
          borderpad: 4,
          font: {
            family: "Inter, sans-serif",
            size: 11,
            color: colorByArch[arch] || "#334155",
          },
        });
      }

      const xs = points.map((p) => p.latency);
      const ys = points.map((p) => p.cost);
      const xMin = Math.min(...xs);
      const xMax = Math.max(...xs);
      const yMin = Math.min(...ys);
      const yMax = Math.max(...ys);
      const xPad = (xMax - xMin || 1) * 0.08;
      const yPad = (yMax - yMin || 1) * 0.12;

      const trendLayout = {
        title: {
          text: "Architecture Trend in Cost vs Speed",
          font: { family: "Inter, sans-serif", size: 26, color: "#0f172a" },
        },
        paper_bgcolor: "white",
        plot_bgcolor: "white",
        margin: { l: 78, r: 20, t: 62, b: 60 },
        xaxis: {
          title: { text: "Duration (s/task)", font: { family: "Inter, sans-serif", size: 16, color: "#1f2937" } },
          tickfont: { family: "Inter, sans-serif", size: 13, color: "#334155" },
          range: [Math.max(0, xMin - xPad), xMax + xPad],
          fixedrange: true,
          gridcolor: "rgba(148,163,184,0.24)",
        },
        yaxis: {
          title: { text: "Cost ($/task)", font: { family: "Inter, sans-serif", size: 16, color: "#1f2937" } },
          tickfont: { family: "Inter, sans-serif", size: 13, color: "#334155" },
          tickformat: ".4f",
          range: [Math.max(0, yMin - yPad), yMax + yPad],
          fixedrange: true,
          gridcolor: "rgba(148,163,184,0.24)",
        },
        legend: {
          title: { text: "Architecture" },
          orientation: "h",
          y: -0.2,
          x: 0,
          font: { family: "Inter, sans-serif", size: 12, color: "#334155" },
        },
        hoverlabel: {
          bgcolor: "rgba(17,24,39,0.94)",
          bordercolor: "#0f172a",
          font: { color: "#f8fafc", size: 12 },
          align: "left",
        },
        annotations: [...trendArrows, ...trendDeltaLabels],
      };

      Plotly.newPlot(trendRoot, traces, trendLayout, {
        responsive: true,
        displayModeBar: false,
        scrollZoom: false,
      });

      const summaryByArch = new Map(archSummary.map((a) => [a.arch, a]));
      const accX = archOrder.filter((a) => summaryByArch.has(a)).map((a) => archLabels[a] || a);
      const accY = archOrder.filter((a) => summaryByArch.has(a)).map((a) => summaryByArch.get(a).accuracy);
      const accColors = archOrder.filter((a) => summaryByArch.has(a)).map((a) => colorByArch[a] || "#666");
      const upper = archOrder.filter((a) => summaryByArch.has(a)).map((a) => summaryByArch.get(a).accuracy_max - summaryByArch.get(a).accuracy);
      const lower = archOrder.filter((a) => summaryByArch.has(a)).map((a) => summaryByArch.get(a).accuracy - summaryByArch.get(a).accuracy_min);

      const accTrace = {
        type: "bar",
        x: accX,
        y: accY,
        marker: { color: accColors, opacity: 0.88, line: { color: "#fff", width: 1.2 } },
        error_y: {
          type: "data",
          symmetric: false,
          array: upper,
          arrayminus: lower,
          visible: true,
          color: "rgba(55,65,81,0.9)",
          thickness: 1.4,
          width: 4,
        },
        hovertemplate: "<b>%{x}</b><br>Accuracy: %{y:.1f}%<extra></extra>",
        showlegend: false,
      };

      const accLayout = {
        title: {
          text: "Architecture Accuracy",
          font: { family: "Inter, sans-serif", size: 24, color: "#0f172a" },
        },
        paper_bgcolor: "white",
        plot_bgcolor: "white",
        margin: { l: 68, r: 10, t: 62, b: 60 },
        xaxis: {
          title: { text: "Architecture", font: { family: "Inter, sans-serif", size: 15, color: "#1f2937" } },
          tickfont: { family: "Inter, sans-serif", size: 12, color: "#334155" },
          fixedrange: true,
        },
        yaxis: {
          title: { text: "Accuracy (%)", font: { family: "Inter, sans-serif", size: 15, color: "#1f2937" } },
          tickfont: { family: "Inter, sans-serif", size: 12, color: "#334155" },
          range: [0, 100],
          fixedrange: true,
          gridcolor: "rgba(148,163,184,0.24)",
        },
        showlegend: false,
        hoverlabel: {
          bgcolor: "rgba(17,24,39,0.94)",
          bordercolor: "#0f172a",
          font: { color: "#f8fafc", size: 12 },
          align: "left",
        },
      };

      Plotly.newPlot(accRoot, [accTrace], accLayout, {
        responsive: true,
        displayModeBar: false,
        scrollZoom: false,
      });
    })
    .catch(() => {
      trendRoot.textContent = "Failed to load architecture tradeoff data.";
      accRoot.textContent = "Failed to load architecture tradeoff data.";
    });
}

document.addEventListener("DOMContentLoaded", renderArchTradeoffV1);
