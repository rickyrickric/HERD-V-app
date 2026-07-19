Here's a breakdown by screen, then a mockup showing the redesign in action.
Dashboard (home)

KPI cards are flat numbers with no way to tell if 51.57 parasite load is good or bad — a farmer has to already know the scale. Add color-coded status (green/amber/red) per metric against a threshold, plus a small delta vs. last import.
Big empty space between the action row and the bottom buttons is wasted — either fill it with a quick "at-risk animals" preview or shrink the layout.
"Clear/Reset" is a destructive action styled like a passive text link — it should look distinct (e.g., muted red) and confirm before wiping data.

Add Animal

11 identical stacked text fields is a scroll gauntlet with no hints. Group into sections (Identity → Production → Health/Physiology), use numeric keyboards/steppers for numbers, and show the unit inline (e.g., "38.6 °C") instead of only in the label.

Herd Health Overview

Rows show only "Cluster N" — meaningless to a farmer without translation. Add a colored risk dot per row (matching the animal detail's risk indicator) and let the list be sorted/filtered by risk instead of raw cluster ID.

Animal Detail

Good instinct with the risk-indicator dot, but it's unexplained — say why (e.g., "high parasite load") and what to do about it, not just show an orange dot.

Cluster Insights — the chart is the biggest issue

The "Milk Yield vs Fertility" chart connects cluster averages with a line, which visually implies a trend/order between Cluster 0→1→2→3 that doesn't exist — clusters are categorical, not sequential. It should be a bubble/scatter plot: one bubble per cluster, sized by population, colored by cluster, with clean axis labels (yours currently overlap into "8.910 12 14... 2829.4").
Round displayed numbers ("Avg Fertility: 6.699218750000001" should just be "6.70").

Key changes worth carrying into the real app:

Status color on KPI cards — thresholds turn a metric amber/red when it needs attention, instead of a flat number the farmer has to interpret.
Bubble chart instead of line chart — each cluster is a dot (not connected), sized by population, so it can't imply a false ordering or trend between clusters.
Rounded numbers everywhere (6.70, not 6.699218750000001).
Color consistency — use the same cluster color in the donut, the bubble chart, and the risk dot on each animal row, so a user can trace an animal back to its cluster visually without reading text.