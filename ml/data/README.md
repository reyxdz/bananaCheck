# Dataset workspace

Raw images belong in this ignored directory and must never be committed.

Use a folder for each variety and a nested folder for each ripeness stage:

```text
data/
|-- Lakatan/
|   |-- Unripe/
|   |-- Ripe/
|   `-- Overripe/
|-- Saba/
`-- Cavendish/
```

Store individual photographs inside the matching leaf folder. The final class
list must be agreed by the app and model developers before training begins.
