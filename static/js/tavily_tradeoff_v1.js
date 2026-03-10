function renderTavilyTradeoffV1() {
  const shiftRoot = document.getElementById("tavily-shift-chart");
  const accRoot = document.getElementById("tavily-accuracy-chart");
  if (!shiftRoot || !accRoot || typeof Plotly === "undefined") return;

  fetch("static/data/tavily_tradeoff_v1.json")
    .then((r) => r.json())
    .then((payload) => {
      const points = payload.scatter_points || [];
      const archOrder = payload.arch_order || ["P&E", "crag", "lats"];
      const archLabels = payload.arch_labels || { "P&E": "Plan-and-Execute", crag: "CRAG", lats: "LATS" };
      const modelOrder = payload.model_order || [];
      const accArch = payload.accuracy_arch || {};
      const accModelPoints = payload.accuracy_model_points || [];

      if (!points.length) {
        shiftRoot.textContent = "No Tavily shift data available.";
        accRoot.textContent = "No Tavily accuracy data available.";
        return;
      }

      const archColor = {
        lats: "#4e79a7",
        crag: "#e15759",
        "P&E": "#76b041",
      };
      const baseHeight = Math.min(shiftRoot.clientHeight || 500, accRoot.clientHeight || 500);
      const plotHeight = Math.max(420, baseHeight);
      const archSymbol = {
        lats: "circle",
        crag: "square",
        "P&E": "diamond",
      };

      const rank = new Map(modelOrder.map((m, i) => [m, i]));
      const byArch = new Map();
      points.forEach((p) => {
        const arch = p.arch;
        if (!byArch.has(arch)) byArch.set(arch, []);
        byArch.get(arch).push(p);
      });

      const xs = points.map((p) => p.duration_change_pct);
      const ys = points.map((p) => p.cost_change_pct);
      const xMin = Math.min(...xs);
      const xMax = Math.max(...xs);
      const yMin = Math.min(...ys);
      const yMax = Math.max(...ys);
      const xPad = (xMax - xMin || 1) * 0.12;
      const yPad = (yMax - yMin || 1) * 0.12;
      const xLo = xMin - xPad;
      const xHi = xMax + xPad;
      const yLo = yMin - yPad;
      const yHi = yMax + yPad;

      function discreteColorscale(colors) {
        if (!colors.length) return [[0, "#ffffff"], [1, "#ffffff"]];
        const out = [];
        const n = colors.length;
        for (let i = 0; i < n; i += 1) {
          const c = colors[i];
          const left = i / n;
          const right = (i + 1) / n;
          out.push([left, c], [right, c]);
        }
        return out;
      }

      const shadedArchs = archOrder.filter((arch) => byArch.has(arch));
      const archCoords = new Map(
        shadedArchs.map((arch) => [
          arch,
          byArch.get(arch).map((r) => [r.duration_change_pct, r.cost_change_pct]),
        ])
      );
      const bgColors = shadedArchs.map((arch) => {
        const c = archColor[arch] || "#94a3b8";
        if (c.startsWith("#") && c.length === 7) {
          const r = parseInt(c.slice(1, 3), 16);
          const g = parseInt(c.slice(3, 5), 16);
          const b = parseInt(c.slice(5, 7), 16);
          return "rgba(" + r + "," + g + "," + b + ",0.20)";
        }
        return c;
      });

      const gridRes = 90;
      const gridX = Array.from({ length: gridRes }, (_v, i) => xLo + ((xHi - xLo) * i) / (gridRes - 1));
      const gridY = Array.from({ length: gridRes }, (_v, i) => yLo + ((yHi - yLo) * i) / (gridRes - 1));
      const z = gridY.map((yv) => {
        return gridX.map((xv) => {
          let bestIdx = 0;
          let bestDist = Number.POSITIVE_INFINITY;
          shadedArchs.forEach((arch, idx) => {
            const coords = archCoords.get(arch) || [];
            coords.forEach((pt) => {
              const dx = xv - pt[0];
              const dy = yv - pt[1];
              const d = dx * dx + dy * dy;
              if (d < bestDist) {
                bestDist = d;
                bestIdx = idx;
              }
            });
          });
          return bestIdx;
        });
      });

      const backgroundTrace = {
        type: "heatmap",
        x: gridX,
        y: gridY,
        z: z,
        colorscale: discreteColorscale(bgColors),
        showscale: false,
        hoverinfo: "skip",
        opacity: 1,
        zsmooth: false,
      };

      const traces = archOrder
        .filter((arch) => byArch.has(arch))
        .map((arch) => {
          const rows = byArch.get(arch).slice().sort((a, b) => {
            const ai = rank.has(a.model) ? rank.get(a.model) : 999;
            const bi = rank.has(b.model) ? rank.get(b.model) : 999;
            if (ai !== bi) return ai - bi;
            return String(a.model).localeCompare(String(b.model));
          });
          return {
            type: "scatter",
            mode: "markers",
            name: archLabels[arch] || arch,
            x: rows.map((r) => r.duration_change_pct),
            y: rows.map((r) => r.cost_change_pct),
            marker: {
              size: 10,
              color: archColor[arch] || "#64748b",
              symbol: archSymbol[arch] || "circle",
              line: { color: "#ffffff", width: 1.2 },
              opacity: 0.9,
            },
            customdata: rows.map((r) => [r.model, r.accuracy_change_abs]),
            hovertemplate:
              "<b>" + (archLabels[arch] || arch) + "</b><br>" +
              "Model: %{customdata[0]}<br>" +
              "Duration shift: %{x:.1f}%<br>" +
              "Cost shift: %{y:.1f}%<br>" +
              "Accuracy change: %{customdata[1]:+.1f}%<extra></extra>",
          };
        });

      const shiftLayout = {
        title: {
          text: "Latency-Cost Shift with Web Search",
          font: { family: "Inter, sans-serif", size: 24, color: "#0f172a" },
        },
        height: plotHeight,
        paper_bgcolor: "white",
        plot_bgcolor: "white",
        margin: { l: 76, r: 16, t: 54, b: 72 },
        xaxis: {
          title: { text: "Duration change (%)", font: { family: "Inter, sans-serif", size: 14, color: "#1f2937" } },
          tickfont: { family: "Inter, sans-serif", size: 12, color: "#334155" },
          range: [xLo, xHi],
          fixedrange: true,
          zeroline: true,
          zerolinecolor: "rgba(15,23,42,0.55)",
          zerolinewidth: 1.4,
          gridcolor: "rgba(148,163,184,0.22)",
        },
        yaxis: {
          title: { text: "Cost change (%)", font: { family: "Inter, sans-serif", size: 14, color: "#1f2937" } },
          tickfont: { family: "Inter, sans-serif", size: 12, color: "#334155" },
          range: [yLo, yHi],
          fixedrange: true,
          zeroline: true,
          zerolinecolor: "rgba(15,23,42,0.55)",
          zerolinewidth: 1.4,
          gridcolor: "rgba(148,163,184,0.22)",
        },
        legend: {
          title: { text: "Architecture" },
          orientation: "h",
          y: -0.24,
          x: 0,
          font: { family: "Inter, sans-serif", size: 12, color: "#334155" },
        },
        hoverlabel: {
          bgcolor: "rgba(17,24,39,0.94)",
          bordercolor: "#0f172a",
          font: { color: "#f8fafc", size: 12 },
          align: "left",
        },
      };

      Plotly.newPlot(shiftRoot, [backgroundTrace, ...traces], shiftLayout, {
        responsive: true,
        displayModeBar: false,
        scrollZoom: false,
      });

      const accX = archOrder.filter((a) => Object.prototype.hasOwnProperty.call(accArch, a)).map((a) => archLabels[a] || a);
      const accY = archOrder.filter((a) => Object.prototype.hasOwnProperty.call(accArch, a)).map((a) => accArch[a].accuracy_delta_abs);
      const accColors = archOrder.filter((a) => Object.prototype.hasOwnProperty.call(accArch, a)).map((a) => archColor[a] || "#64748b");

      const barTrace = {
        type: "bar",
        x: accX,
        y: accY,
        marker: { color: accColors, opacity: 0.82, line: { color: "#ffffff", width: 1.2 } },
        hovertemplate: "<b>%{x}</b><br>Accuracy change: %{y:+.1f}%<extra></extra>",
        showlegend: false,
      };

      const pointsByArch = new Map();
      accModelPoints.forEach((r) => {
        const key = r.arch;
        if (!pointsByArch.has(key)) pointsByArch.set(key, []);
        pointsByArch.get(key).push(r);
      });

      const dotX = [];
      const dotY = [];
      const dotText = [];
      archOrder.forEach((arch) => {
        const rows = pointsByArch.get(arch) || [];
        rows
          .slice()
          .sort((a, b) => {
            const ai = rank.has(a.model) ? rank.get(a.model) : 999;
            const bi = rank.has(b.model) ? rank.get(b.model) : 999;
            if (ai !== bi) return ai - bi;
            return String(a.model).localeCompare(String(b.model));
          })
          .forEach((row) => {
            dotX.push(archLabels[arch] || arch);
            dotY.push(row.accuracy_change_abs);
            dotText.push(row.model);
          });
      });

      const dotsTrace = {
        type: "scatter",
        mode: "markers",
        x: dotX,
        y: dotY,
        marker: {
          size: 8,
          color: "#111827",
          opacity: 0.9,
          line: { color: "#ffffff", width: 1 },
        },
        customdata: dotText,
        hovertemplate: "Model: %{customdata}<br>Accuracy change: %{y:+.1f}%<extra></extra>",
        showlegend: false,
      };

      const yVals = accY.concat(dotY);
      const yMin2 = Math.min(...yVals, 0);
      const yMax2 = Math.max(...yVals, 0);
      const yPad2 = (yMax2 - yMin2 || 1) * 0.15;

      const accLayout = {
        title: {
          text: "Accuracy Change with Web Search",
          font: { family: "Inter, sans-serif", size: 24, color: "#0f172a" },
        },
        height: plotHeight,
        paper_bgcolor: "white",
        plot_bgcolor: "white",
        margin: { l: 68, r: 12, t: 54, b: 58 },
        xaxis: {
          title: { text: "Architecture", font: { family: "Inter, sans-serif", size: 14, color: "#1f2937" } },
          tickfont: { family: "Inter, sans-serif", size: 12, color: "#334155" },
          fixedrange: true,
        },
        yaxis: {
          title: { text: "Accuracy change (%)", font: { family: "Inter, sans-serif", size: 14, color: "#1f2937" } },
          tickfont: { family: "Inter, sans-serif", size: 12, color: "#334155" },
          range: [yMin2 - yPad2, yMax2 + yPad2],
          fixedrange: true,
          zeroline: true,
          zerolinecolor: "rgba(15,23,42,0.55)",
          zerolinewidth: 1.4,
          gridcolor: "rgba(148,163,184,0.22)",
        },
        hoverlabel: {
          bgcolor: "rgba(17,24,39,0.94)",
          bordercolor: "#0f172a",
          font: { color: "#f8fafc", size: 12 },
          align: "left",
        },
        showlegend: false,
      };

      Plotly.newPlot(accRoot, [barTrace, dotsTrace], accLayout, {
        responsive: true,
        displayModeBar: false,
        scrollZoom: false,
      });
    })
    .catch(() => {
      shiftRoot.textContent = "Failed to load Tavily interactive data.";
      accRoot.textContent = "Failed to load Tavily interactive data.";
    });
}

document.addEventListener("DOMContentLoaded", renderTavilyTradeoffV1);
