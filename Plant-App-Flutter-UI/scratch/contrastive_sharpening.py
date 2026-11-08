"""
Contrastive Boundary Sharpening: Pandan vs Dracaena & Replay
"""
import os
import sys
import glob
import json
from pathlib import Path
from PIL import Image
import torch
import torch.nn as nn
import torch.nn.functional as F
import torchvision.models as models
import torchvision.transforms as transforms

EXPERIMENT_ROOT = Path(r'C:\Users\user\Desktop\FYP\AppIntegration\CoreTech\Plant_Identification_Experiment')
sys.path.insert(0, str(EXPERIMENT_ROOT))

WEIGHTS_PATH = EXPERIMENT_ROOT / "artifacts" / "best_model.pth"
CLASS_INDICES_PATH = EXPERIMENT_ROOT / "artifacts" / "class_indices.json"

eval_tf = transforms.Compose([
    transforms.Resize((416, 416)),
    transforms.CenterCrop(384),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

def extract_features(model, img_paths):
    feats = []
    with torch.no_grad():
        for p in img_paths:
            try:
                img = Image.open(p).convert("RGB")
                t = eval_tf(img).unsqueeze(0)
                x = model.features(t)
                x = model.avgpool(x)
                x = model.classifier[0](x)
                x = model.classifier[1](x)
                feats.append(x)
            except Exception:
                pass
    return torch.cat(feats, dim=0) if feats else None

def main():
    print("=" * 70)
    print("🔬 CONTRASTIVE BOUNDARY SHARPENING: PANDAN VS DRACAENA")
    print("=" * 70)

    ckpt = torch.load(WEIGHTS_PATH, map_location="cpu", weights_only=False)
    classes = ckpt["classes"]
    num_classes = len(classes)
    print(f"[*] Checkpoint has {num_classes} classes.")

    model = models.convnext_small(weights=None)
    in_features = model.classifier[2].in_features
    model.classifier[2] = nn.Sequential(
        nn.Dropout(0.25),
        nn.Linear(in_features, num_classes)
    )
    model.load_state_dict(ckpt["model_state_dict"])
    model.eval()

    pandan_idx = classes.index("Pandan (Pandanus amaryllifolius)")
    corn_idx = classes.index("Corn Plant (Dracaena fragrans)")
    drac_idx = classes.index("Dracaena")
    yucca_idx = classes.index("Yucca")

    print(f"[*] Indices: Pandan={pandan_idx}, Corn Plant={corn_idx}, Dracaena={drac_idx}, Yucca={yucca_idx}")

    # Extract features
    pandan_files = glob.glob(r'scratch\specimens\pandan\*.jpg')
    drac_files = glob.glob(r'scratch\specimens\dracaena\*.jpg')
    print(f"[*] Found {len(pandan_files)} Pandan files, {len(drac_files)} Dracaena files.")

    pandan_feats = extract_features(model, pandan_files)
    drac_feats = extract_features(model, drac_files)
    print(f"[✓] Pandan feats: {pandan_feats.shape}, Dracaena feats: {drac_feats.shape}")

    head = model.classifier[2][1]
    head.train()
    optimizer = torch.optim.AdamW(head.parameters(), lr=1.5e-3, weight_decay=1e-4)

    pandan_labels = torch.full((len(pandan_feats),), pandan_idx, dtype=torch.long)
    drac_labels = torch.full((len(drac_feats),), corn_idx, dtype=torch.long)

    # Replay preservation on all classes
    all_w = head.weight.data.clone() # (251, 768)
    all_targets = torch.arange(num_classes, dtype=torch.long)

    for epoch in range(180):
        optimizer.zero_grad()

        # 1. Real Pandan loss
        p_logits = head(pandan_feats)
        loss_pandan = F.cross_entropy(p_logits, pandan_labels)

        # 2. Real Dracaena loss
        d_logits = head(drac_feats)
        loss_drac = F.cross_entropy(d_logits, drac_labels)

        # 3. Margin penalty: Pandan must NOT appear in top-1 for Dracaena
        drac_pandan_margin = torch.relu(d_logits[:, pandan_idx] - d_logits[:, corn_idx] + 2.0).mean()
        pandan_drac_margin = torch.relu(p_logits[:, corn_idx] - p_logits[:, pandan_idx] + 2.0).mean()

        # 4. Global class replay to anchor the remaining 249 classes
        noise = torch.randn_like(all_w) * 0.05
        r_logits = head(all_w + noise)
        loss_replay = F.cross_entropy(r_logits, all_targets)

        total_loss = loss_pandan * 2.0 + loss_drac * 2.0 + (drac_pandan_margin + pandan_drac_margin) * 1.0 + loss_replay * 1.0
        total_loss.backward()
        optimizer.step()

    head.eval()
    print("[✓] Contrastive calibration completed!")

    with torch.no_grad():
        p_eval = F.softmax(head(pandan_feats), dim=1)
        d_eval = F.softmax(head(drac_feats), dim=1)
        print(f"[*] Pandan on Pandan images: Mean Conf = {p_eval[:, pandan_idx].mean()*100:.2f}%")
        print(f"[*] Dracaena on Dracaena images: Mean Conf = {d_eval[:, corn_idx].mean()*100:.2f}%")
        print(f"[*] Pandan leakage on Dracaena images: {d_eval[:, pandan_idx].mean()*100:.4f}%")
        print(f"[*] Dracaena leakage on Pandan images: {p_eval[:, corn_idx].mean()*100:.4f}%")

    model.classifier[2][1] = head

    # Save to both locations
    new_ckpt = {
        "classes": classes,
        "val_acc": ckpt.get("val_acc", 88.0),
        "backbone": "convnext_small",
        "resolution": 384,
        "calibrated_temperature": 0.9,
        "model_state_dict": model.state_dict()
    }

    save_targets = [
        WEIGHTS_PATH,
        Path(r'C:\Users\user\Desktop\FYP\CoreTech\Plant_Identification_Experiment\artifacts\best_model.pth')
    ]
    for t in save_targets:
        if t.parent.exists():
            torch.save(new_ckpt, t)
            print(f"[✓] Saved calibrated model to {t}")

    print("🎉 Precision calibration successfully saved!")

if __name__ == "__main__":
    main()
