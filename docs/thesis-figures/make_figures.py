import json, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

SRC = "ml/output"
OUT = "ml/output"

# Thesis spelling: the repo labels say Cordova/Senorita; the manuscript uses
# Cardava/Senorita with a tilde. Keep the figures consistent with the prose.
PRETTY = {"Cordova": "Cardava", "Senorita": "Señorita", "NotBanana": "Not a banana"}
def pretty(lbl):
    if lbl in PRETTY: return PRETTY[lbl]
    v, _, r = lbl.partition("_")
    return f"{PRETTY.get(v, v)} – {r}"

d = json.load(open(f"{SRC}/evaluation_metrics.json"))
labels = [pretty(r["class"]) for r in d["per_class"]]
cm = np.array(d["confusion_matrix"])

# ---- Figure 4.1: confusion matrix -------------------------------------
fig, ax = plt.subplots(figsize=(12.5, 10.5))
im = ax.imshow(cm, cmap="Blues", vmin=0, vmax=cm.max())
ax.set_xticks(range(len(labels))); ax.set_yticks(range(len(labels)))
ax.set_xticklabels(labels, rotation=90, fontsize=9)
ax.set_yticklabels(labels, fontsize=9)
ax.set_xlabel("Predicted label", fontsize=11)
ax.set_ylabel("True label", fontsize=11)
ax.set_title("Confusion Matrix of True Label and Predicted Label\n"
             f"(19 classes, {d['num_samples']} test images, "
             f"{d['overall_accuracy']*100:.2f}% accuracy)", fontsize=12, pad=14)
thr = cm.max() / 2
for i in range(len(labels)):
    for j in range(len(labels)):
        v = cm[i][j]
        if v:
            ax.text(j, i, str(v), ha="center", va="center", fontsize=8,
                    color="white" if v > thr else "black",
                    fontweight="bold" if i != j else "normal")
fig.colorbar(im, ax=ax, shrink=0.8)
fig.tight_layout()
fig.savefig(f"{OUT}/figure-4-1-confusion-matrix.png", dpi=200)
plt.close(fig)

# ---- Figure 4.2: training / validation accuracy and loss ---------------
h = json.load(open(f"{SRC}/training_history.json"))
ep = range(1, len(h["accuracy"]) + 1)
FT = 11  # fine-tuning begins at epoch 11

fig, (a1, a2) = plt.subplots(1, 2, figsize=(12, 4.6))
for ax, (tr, va, name) in zip(
        (a1, a2),
        [("accuracy", "val_accuracy", "Accuracy"), ("loss", "val_loss", "Loss")]):
    ax.plot(ep, h[tr], "o-", ms=4, label=f"Training {name.lower()}")
    ax.plot(ep, h[va], "s-", ms=4, label=f"Validation {name.lower()}")
    ax.axvline(FT, color="grey", ls="--", lw=1)
    ax.annotate("fine-tuning begins", xy=(FT, ax.get_ylim()[1]),
                xytext=(FT + 0.2, ax.get_ylim()[1]), fontsize=8,
                color="grey", va="top")
    ax.set_xlabel("Epoch"); ax.set_ylabel(name)
    ax.set_title(f"Training and Validation {name}")
    ax.grid(alpha=0.3); ax.legend(fontsize=9)
fig.tight_layout()
fig.savefig(f"{OUT}/figure-4-2-training-curves.png", dpi=200)
plt.close(fig)

print("accuracy  final train %.4f  final val %.4f  best val %.4f (epoch %d)"
      % (h["accuracy"][-1], h["val_accuracy"][-1], max(h["val_accuracy"]),
         h["val_accuracy"].index(max(h["val_accuracy"])) + 1))
print("loss      final train %.4f  final val %.4f  min val %.4f (epoch %d)"
      % (h["loss"][-1], h["val_loss"][-1], min(h["val_loss"]),
         h["val_loss"].index(min(h["val_loss"])) + 1))
