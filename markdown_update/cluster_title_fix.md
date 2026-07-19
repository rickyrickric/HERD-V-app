# Fix: cluster screen title doesn't update with dropdown

## Bug

On the cluster explorer screen, selecting a different cluster from the
dropdown (e.g. `Cluster 0` → `Cluster 2`) updates the list and the dropdown
label correctly, but the AppBar title stays stuck on `Cluster 0`.

## Cause

Two different sources of truth for the same value:

- The **title** is set once from the value passed in at navigation time
  (e.g. a constructor/route argument like `initialCluster`) and never
  rebuilt.
- The **dropdown** reads/writes its own local `State` field via `setState`,
  so only the dropdown re-renders when the selection changes.

## Fix

Make the title read from the same state field the dropdown uses, so there's
a single source of truth.

```dart
// Before — title is baked in from nav args, dropdown updates a separate variable
appBar: AppBar(title: Text(widget.initialCluster)),

// After — both title and dropdown read the one selectedCluster state
appBar: AppBar(
  title: Text(selectedCluster == 'All' ? 'All animals' : selectedCluster),
),
...
DropdownButton<String>(
  value: selectedCluster,
  items: clusterOptions
      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
      .toList(),
  onChanged: (v) => setState(() => selectedCluster = v!),
),
```

Checklist:

- [ ] `selectedCluster` is declared in the `State` object, not passed down
      as a `final` constructor field.
- [ ] Any constructor argument (e.g. `initialCluster`) is only used to
      **initialize** `selectedCluster` in `initState()` — nothing else reads
      it directly afterward.
- [ ] The AppBar `Text` widget reads `selectedCluster`, not the constructor
      field.
- [ ] The dropdown's `onChanged` calls `setState` on `selectedCluster`.

## Also worth reconsidering

The title and the dropdown currently show the same information twice. Once
a cluster is picked from the dropdown, a static/generic title (e.g.
`Herd clusters` or `Cluster explorer`) removes the duplication entirely —
the dropdown becomes the single, obvious place to see and change the
current filter, with nothing else that can drift out of sync with it.

## Side note

In the `Cluster 2` screenshot, `L0040` shows an amber risk dot while every
other animal in that cluster shows red. Worth confirming this is a genuine
lower-risk outlier rather than a stale/miscalculated risk score.