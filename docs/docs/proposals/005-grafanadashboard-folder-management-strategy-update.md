---
title: Update GrafanaDashboard folder management strategy
linkTitle: Update GrafanaDashboard folder strategy
---

## Summary

Update the folder creation/selection mechanism in the GrafanaDashboard CRD by introducing the possibility to target a GrafanaFolder CR declared in the cluster.

This document contains the complete design required to support targeting a GrafanaFolder as a reference. This method would permit to handle the subfolder feature from Grafana (version >= 10) if combined with the [GrafanaFolder CRD proposal](./004-grafanafolder-parent-folder-management.md).

The suggested new features are:

- Use a `folderRef` field to target a folder deployed thanks to the GrafanaFolder CR.
- Use a `folderUID` field to target an existing folder in Grafana.
- Enable or disable folder creation from GrafanaDashboard by adding a field `createFolder` (default: true for retrocompatibility). This field cannot be false if `folderUID` and `folderRef` are not set in the GrafanaDashboard manifest.

## Info

status: Suggested <!-- TODO: update when validated by maintainers -->

## Motivation

The GrafanaDashboard CRD currently deployed by the operator allows to:

- Create a folder at the root level of Grafana if it does not exist. If no folder is declared in the operator, the namespace of the folder will be used as a the folder name.
- Create a dashboard in the previously created folder.

With the arrival of Grafana 11, the subfolders feature becomes stable and is enabled by default. However, this is not handled by the grafana-operator yet and its current implementation creates unwanted behavior by creating an intermediate level folder (the namespace folder) when declared.

## Proposal

The proposal of this pull request is to update the GrafanaDashboard CR to:

- Add a field `folderRef` which permits to target an existing GrafanaFolder CR where the dashboard will be created.
- Add a field `folderUID` which permits to target an existing folder in Grafana by it UID.
- Add the possibility to disable the folder creation if the `folderRef` or `folderUID` are set.

### Proposal 1: Target an existing folder in Grafana using its reference in the operator

The first proposal is to add a `folderRef` field in the GrafanaDashboard CRD which could request the GrafanaFolder CR by its name, retrieve the id and ask for the folder creation to the Grafana API.
We can find the Grafana API reference for:

- [The creation](https://grafana.com/docs/grafana/latest/developers/http_api/dashboard/#create--update-dashboard)

We have found that the grafana golang sdk already handles the `folderUID` field natively for dashboard creation: https://github.com/grafana/grafana-openapi-client-go/blob/main/models/save_dashboard_command.go

With this field implemented, the GrafanaDashboard CRD would look like this:

```yaml
---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaFolder
metadata:
  name: parent-folder
spec:
  instanceSelector:
    matchLabels:
      dashboards: "grafana"
  title: "Parent"

---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: cr-dashboard-ref
  namespace: namespace
  labels:
    dashboards: "grafana"
spec:
  folderRef: "parent-folder"
  createFolder: false # could be set to true see proposal #3
  instanceSelector:
    matchLabels:
      dashboards: "grafana"
  json: |
    {
      "id": null,
      "title": "Simple Dashboard REF",
      "tags": [],
      "style": "dark",
      "timezone": "browser",
      "editable": true,
      "hideControls": false,
      "graphTooltip": 1,
      "panels": [],
      "time": {
        "from": "now-6h",
        "to": "now"
      },
      "timepicker": {
        "time_options": [],
        "refresh_intervals": []
      },
      "templating": {
        "list": []
      },
      "annotations": {
        "list": []
      },
      "refresh": "5s",
      "schemaVersion": 17,
      "version": 0,
      "links": []
    }
```

### Proposal 2: Target an existing folder in Grafana using its UID

The second proposal is to add a folderUID field in the GrafanaDashboard CRD which could request the Grafana API to create and reconcile the folder.
We can find the Grafana API reference for:

- [The creation](https://grafana.com/docs/grafana/latest/developers/http_api/dashboard/#create--update-dashboard)

We have found that the grafana golang sdk already handle the folderUID field natively for dashboard creation: https://github.com/grafana/grafana-openapi-client-go/blob/main/models/import_dashboard_request.go

With this field implemented, the CRD GrafanaDashboard would look like this:

```yaml
---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: cr-dashboard-uid
  namespace: namespace
  labels:
    dashboards: "grafana"
spec:
  folderUID: "test123456789" # ID of the parent Folder in Grafana
  createFolder: false # could be set to true see proposal #3
  instanceSelector:
    matchLabels:
      dashboards: "grafana"
  json: |
    {
      "id": null,
      "title": "Simple Dashboard UID",
      "tags": [],
      "style": "dark",
      "timezone": "browser",
      "editable": true,
      "hideControls": false,
      "graphTooltip": 1,
      "panels": [],
      "time": {
        "from": "now-6h",
        "to": "now"
      },
      "timepicker": {
        "time_options": [],
        "refresh_intervals": []
      },
      "templating": {
        "list": []
      },
      "annotations": {
        "list": []
      },
      "refresh": "5s",
      "schemaVersion": 17,
      "version": 0,
      "links": []
    }
```

> Note: this field is mutually exclusive with the folderRef presented in the first proposal.

### Proposal 3: Add the possibility to disable folder creation if field folderRef and folderUID are set

The current behavior of the Grafana Dashboard CR is to find if a folder with the name describes in the `folder` field exists and create the dashboard in it.
There are two additional behaviors:

- If the folder does not exist, it is created by the operator.
- If the folder is not specified, the default value of the field becomes the name of the namespace.

When we are in the dashboard creation loop, we first pass through the `GetOrCreateFolder` and then, once the folder is created (or already exists), we create the dashboard with the `grafanaClient.Dashboards.PostDashboard(<...>)` method. If we implement the `folderUID` and/or `folderRef` method, we would have two additional behaviors:

- Create the dashboard in the parent folder directly (without an intermediate folder)
- Keep the current behavior by creating the folder and create a dashboard in it

Here is the currently created pattern:

```bash
# current option #1
.
L namespace
  L cr-dashboard

# current option #2
.
L existing-folder
  L cr-dashboard-2
```

With the associated manifests:

```yaml
---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: cr-dashboard
  namespace: namespace
  labels:
    dashboards: "grafana"
spec:
  # folder: namespace (default value)
  # createFolder: true (default value)
  instanceSelector:
    matchLabels:
      dashboards: "grafana"
  json: |
    {
      "id": null,
      "title": "Simple Dashboard",
      "tags": [],
      "style": "dark",
      "timezone": "browser",
      "editable": true,
      "hideControls": false,
      "graphTooltip": 1,
      "panels": [],
      "time": {
        "from": "now-6h",
        "to": "now"
      },
      "timepicker": {
        "time_options": [],
        "refresh_intervals": []
      },
      "templating": {
        "list": []
      },
      "annotations": {
        "list": []
      },
      "refresh": "5s",
      "schemaVersion": 17,
      "version": 0,
      "links": []
    }

---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: cr-dashboard-2
  labels:
    dashboards: "grafana"
spec:
  folder: existing-folder
  # createFolder: true (default value)
  instanceSelector:
    matchLabels:
      dashboards: "grafana"
  json: |
    {
      "id": null,
      "title": "Simple Dashboard 2",
      "tags": [],
      "style": "dark",
      "timezone": "browser",
      "editable": true,
      "hideControls": false,
      "graphTooltip": 1,
      "panels": [],
      "time": {
        "from": "now-6h",
        "to": "now"
      },
      "timepicker": {
        "time_options": [],
        "refresh_intervals": []
      },
      "templating": {
        "list": []
      },
      "annotations": {
        "list": []
      },
      "refresh": "5s",
      "schemaVersion": 17,
      "version": 0,
      "links": []
    }
```

Now, we want to create our dashboard in a parent folder. There are two scenario:

First, we want to create our dashboard in a specific folder using `folderRef`. We don't want an intermediate folder.

```bash
# first evolution
.
L existing-folder
  L cr-grafanafolder-created-folder
    L cr-dashboard-3
```

The manifests will look like this:

```yaml
---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaFolder
metadata:
  name: cr-grafanafolder-created-folder
spec:
  instanceSelector:
    matchLabels:
      dashboards: "grafana"
  title: "cr-grafanafolder-created-folder"
  parentFolderUID: "<existing_folder_uid>"
---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: cr-dashboard-3
  labels:
    dashboards: "grafana"
spec:
  folderRef: cr-grafanafolder-created-folder
  createFolder: false
  instanceSelector:
    matchLabels:
      dashboards: "grafana"
  json: |
    {
      "id": null,
      "title": "Simple Dashboard 3",
      "tags": [],
      "style": "dark",
      "timezone": "browser",
      "editable": true,
      "hideControls": false,
      "graphTooltip": 1,
      "panels": [],
      "time": {
        "from": "now-6h",
        "to": "now"
      },
      "timepicker": {
        "time_options": [],
        "refresh_intervals": []
      },
      "templating": {
        "list": []
      },
      "annotations": {
        "list": []
      },
      "refresh": "5s",
      "schemaVersion": 17,
      "version": 0,
      "links": []
    }
```

And now, with the creation of the intermediate folder:

```bash
# second evolution
.
L existing-folder
  L cr-grafanafolder-created-folder
    L cr-grafanadashboard-created-folder
      L cr-dashboard-4

.
L existing-folder
  L cr-grafanafolder-created-folder
    L namespace
      L cr-dashboard-5
```

The associated yaml file:

```yaml
---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaFolder
metadata:
  name: cr-grafanafolder-created-folder
spec:
  instanceSelector:
    matchLabels:
      dashboards: "grafana"
  title: "cr-grafanafolder-created-folder"
  parentFolderUID: "<existing_folder_uid>"

---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: cr-dashboard-4
  labels:
    dashboards: "grafana"
spec:
  folder: cr-grafanadashboard-created-folder
  # createFolder: true (default value)
  folderRef: cr-grafanafolder-created-folder
  instanceSelector:
    matchLabels:
      dashboards: "grafana"
  json: |
    {
      "id": null,
      "title": "Simple Dashboard 4",
      "tags": [],
      "style": "dark",
      "timezone": "browser",
      "editable": true,
      "hideControls": false,
      "graphTooltip": 1,
      "panels": [],
      "time": {
        "from": "now-6h",
        "to": "now"
      },
      "timepicker": {
        "time_options": [],
        "refresh_intervals": []
      },
      "templating": {
        "list": []
      },
      "annotations": {
        "list": []
      },
      "refresh": "5s",
      "schemaVersion": 17,
      "version": 0,
      "links": []
    }

---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: cr-dashboard-5
  namespace: namespace
  labels:
    dashboards: "grafana"
spec:
  # folder: namespace (default value)
  # createFolder: true (default value)
  folderRef: cr-grafanafolder-created-folder
  instanceSelector:
    matchLabels:
      dashboards: "grafana"
  json: |
    {
      "id": null,
      "title": "Simple Dashboard 5",
      "tags": [],
      "style": "dark",
      "timezone": "browser",
      "editable": true,
      "hideControls": false,
      "graphTooltip": 1,
      "panels": [],
      "time": {
        "from": "now-6h",
        "to": "now"
      },
      "timepicker": {
        "time_options": [],
        "refresh_intervals": []
      },
      "templating": {
        "list": []
      },
      "annotations": {
        "list": []
      },
      "refresh": "5s",
      "schemaVersion": 17,
      "version": 0,
      "links": []
    }
```

*Warning: if the field `createFolder` is set to false and `folderUID` or `folderRef` are not set. An error should be returned because a dashboard it requires a folder to be created in.*

## Impact on the already existing CRD

By setting the `createFolder` field to `true` as default value, no regression is introduced in the current behavior of the operator. This should be documented to ensure avoiding new user misunderstanding of the behavior of the operator.

However, we recommend to change it to `false` to make the CRD more intuitive. For us, it is better to have a default feature disabled by default than the opposite.

## Decision Outcome

<!-- TODO: to discuss with maintainers -->

## Related discussions

- [PR 1564](https://github.com/grafana/grafana-operator/pull/1564)
- [Issue 1222](https://github.com/grafana/grafana-operator/issues/1222)
- [Issue 1514](https://github.com/grafana/grafana-operator/issues/1514)
