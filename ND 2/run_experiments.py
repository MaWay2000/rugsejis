"""ND2 eksperimentai pagal Dewis ir Viana (2022) straipsnį.

Programa atkuria straipsnyje aprašytus MLP parametrų bandymus su oficialiu
UCI Spambase rinkiniu ir atlieka papildomus standartizavimo bei SVM bandymus.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import sys
import time
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
os.environ.setdefault("TF_DETERMINISTIC_OPS", "1")

import joblib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import sklearn
import tensorflow as tf
from sklearn.metrics import (
    ConfusionMatrixDisplay,
    accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC


ROOT = Path(__file__).resolve().parent
DATA_PATH = ROOT / "data" / "spambase.data"
RESULTS_DIR = ROOT / "results"
FIGURES_DIR = RESULTS_DIR / "figures"
MODELS_DIR = RESULTS_DIR / "models"
SEEDS = [42, 43, 44, 45, 46]
ARTICLE_ACCURACY = 0.95


def load_data() -> tuple[np.ndarray, np.ndarray]:
    data = np.loadtxt(DATA_PATH, delimiter=",")
    x = data[:, :-1].astype(np.float32)
    y = data[:, -1].astype(np.int32)
    if x.shape != (4601, 57):
        raise ValueError(f"Tikėtasi (4601, 57), gauta {x.shape}.")
    if set(np.unique(y)) != {0, 1}:
        raise ValueError("Klasės turi būti 0 ir 1.")
    return x, y


def split_data(x: np.ndarray, y: np.ndarray, seed: int):
    return train_test_split(
        x,
        y,
        test_size=0.30,
        random_state=seed,
        stratify=y,
    )


def set_seed(seed: int) -> None:
    tf.keras.backend.clear_session()
    tf.keras.utils.set_random_seed(seed)


def optimizer(name: str):
    optimizers = {
        "adam": tf.keras.optimizers.Adam,
        "adamax": tf.keras.optimizers.Adamax,
        "nadam": tf.keras.optimizers.Nadam,
        "rmsprop": tf.keras.optimizers.RMSprop,
    }
    return optimizers[name.lower()]()


def build_article_model(
    input_dim: int,
    optimizer_name: str,
    input_activation: str,
    hidden_activation: str,
    architecture: str = "article_a",
) -> tf.keras.Model:
    """Sukuria modelį pagal straipsnio 2, 5 ir 7 pav. aprašymus."""
    model = tf.keras.Sequential(name=architecture)
    model.add(tf.keras.layers.Input(shape=(input_dim,)))

    if architecture == "article_a":
        hidden_units = [5, 5, 5, 5, 5, 4, 3]
        dropout_mode = "none"
    elif architecture == "decrement":
        hidden_units = [10, 9, 8, 7, 6, 5, 4, 3]
        dropout_mode = "none"
    elif architecture == "dropout_each":
        hidden_units = [10, 9, 8, 7, 6, 5, 4, 3]
        dropout_mode = "each"
    elif architecture == "dropout_end":
        hidden_units = [10, 9, 8, 7, 6, 5, 4, 3]
        dropout_mode = "end"
    elif architecture == "compact":
        hidden_units = [64, 32, 16]
        dropout_mode = "none"
    else:
        raise ValueError(f"Nežinoma architektūra: {architecture}")

    for index, units in enumerate(hidden_units):
        if dropout_mode == "each" and index > 0:
            model.add(tf.keras.layers.Dropout(0.2))
            model.add(tf.keras.layers.Flatten())
        activation = input_activation if index == 0 else hidden_activation
        model.add(tf.keras.layers.Dense(units, activation=activation))

    if dropout_mode == "end":
        model.add(tf.keras.layers.Dropout(0.2))
        model.add(tf.keras.layers.Flatten())

    if architecture == "compact":
        model.add(tf.keras.layers.Dense(1, activation="sigmoid"))
    else:
        # Straipsnio lentelėje nurodyti du išvesties sluoksniai.
        model.add(tf.keras.layers.Dense(2, activation="sigmoid"))
        model.add(tf.keras.layers.Dense(1, activation="sigmoid"))
    model.compile(
        optimizer=optimizer(optimizer_name),
        loss="binary_crossentropy",
        metrics=["accuracy", tf.keras.metrics.Precision(name="precision")],
    )
    return model


def evaluate_predictions(
    y_true: np.ndarray, scores: np.ndarray, threshold: float = 0.5
) -> dict[str, float]:
    predicted = (scores >= threshold).astype(np.int32)
    return {
        "accuracy": accuracy_score(y_true, predicted),
        "precision": precision_score(y_true, predicted, zero_division=0),
        "recall": recall_score(y_true, predicted, zero_division=0),
        "f1": f1_score(y_true, predicted, zero_division=0),
        "roc_auc": roc_auc_score(y_true, scores),
    }


def run_mlp(
    x: np.ndarray,
    y: np.ndarray,
    *,
    seed: int,
    experiment: str,
    configuration: str,
    optimizer_name: str = "nadam",
    input_activation: str = "relu",
    hidden_activation: str = "sigmoid",
    batch_size: int = 32,
    epochs: int = 100,
    architecture: str = "article_a",
    standardize: bool = False,
    keep_predictions: bool = False,
) -> tuple[dict[str, object], np.ndarray | None, np.ndarray | None, tf.keras.Model]:
    x_train, x_test, y_train, y_test = split_data(x, y, seed)
    if standardize:
        scaler = StandardScaler()
        x_train = scaler.fit_transform(x_train).astype(np.float32)
        x_test = scaler.transform(x_test).astype(np.float32)

    set_seed(seed)
    model = build_article_model(
        x_train.shape[1],
        optimizer_name,
        input_activation,
        hidden_activation,
        architecture,
    )
    started = time.perf_counter()
    model.fit(
        x_train,
        y_train,
        epochs=epochs,
        batch_size=batch_size,
        verbose=0,
        shuffle=True,
    )
    duration = time.perf_counter() - started
    scores = model.predict(x_test, verbose=0).reshape(-1)
    metrics = evaluate_predictions(y_test, scores, threshold=0.5)
    row: dict[str, object] = {
        "experiment": experiment,
        "configuration": configuration,
        "model": "MLP",
        "seed": seed,
        "optimizer": optimizer_name,
        "input_activation": input_activation,
        "hidden_activation": hidden_activation,
        "batch_size": batch_size,
        "epochs": epochs,
        "architecture": architecture,
        "standardized": standardize,
        "train_size": len(y_train),
        "test_size": len(y_test),
        "duration_seconds": duration,
        **metrics,
    }
    if keep_predictions:
        return row, y_test, scores, model
    return row, None, None, model


def run_svm(x: np.ndarray, y: np.ndarray, seed: int, keep_predictions: bool = False):
    x_train, x_test, y_train, y_test = split_data(x, y, seed)
    model = Pipeline(
        [
            ("scaler", StandardScaler()),
            ("svc", SVC(kernel="rbf", C=10.0, gamma="scale", probability=False)),
        ]
    )
    started = time.perf_counter()
    model.fit(x_train, y_train)
    duration = time.perf_counter() - started
    scores = model.decision_function(x_test)
    metrics = evaluate_predictions(y_test, scores, threshold=0.0)
    row: dict[str, object] = {
        "experiment": "additional",
        "configuration": "SVM RBF C=10",
        "model": "SVM RBF",
        "seed": seed,
        "optimizer": "-",
        "input_activation": "-",
        "hidden_activation": "-",
        "batch_size": 0,
        "epochs": 0,
        "architecture": "SVC",
        "standardized": True,
        "train_size": len(y_train),
        "test_size": len(y_test),
        "duration_seconds": duration,
        **metrics,
    }
    if keep_predictions:
        return row, y_test, scores, model
    return row, None, None, model


def save_confusion_figure(
    y_mlp: np.ndarray,
    scores_mlp: np.ndarray,
    y_svm: np.ndarray,
    scores_svm: np.ndarray,
) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(9, 3.8))
    ConfusionMatrixDisplay.from_predictions(
        y_mlp,
        (scores_mlp >= 0.5).astype(int),
        display_labels=["Teisėtas", "Brukalas"],
        cmap="Blues",
        colorbar=False,
        ax=axes[0],
    )
    axes[0].set_title("MLP pagal straipsnio parametrus")
    axes[0].set_xlabel("Prognozuota klasė")
    axes[0].set_ylabel("Tikroji klasė")
    ConfusionMatrixDisplay.from_predictions(
        y_svm,
        (scores_svm >= 0.0).astype(int),
        display_labels=["Teisėtas", "Brukalas"],
        cmap="Greens",
        colorbar=False,
        ax=axes[1],
    )
    axes[1].set_title("Papildomas SVM RBF")
    axes[1].set_xlabel("Prognozuota klasė")
    axes[1].set_ylabel("Tikroji klasė")
    fig.tight_layout()
    fig.savefig(FIGURES_DIR / "klasifikavimo_matricos.png", dpi=300, bbox_inches="tight")
    plt.close(fig)


def save_summary_figures(summary: pd.DataFrame) -> None:
    table5 = summary[summary["experiment"] == "optimizer_activation"].copy()
    table5 = table5.sort_values("accuracy_mean", ascending=False)
    fig, ax = plt.subplots(figsize=(9, 5))
    ax.barh(table5["configuration"], table5["accuracy_mean"] * 100, color="#376f9e")
    ax.axvline(ARTICLE_ACCURACY * 100, color="#b64242", linestyle="--", label="Straipsnis 95 %")
    ax.set_xlabel("Vidutinis tikslumas, %")
    ax.set_ylabel("")
    ax.set_xlim(50, 100)
    ax.invert_yaxis()
    ax.legend(loc="lower right")
    ax.grid(axis="x", alpha=0.25)
    fig.tight_layout()
    fig.savefig(FIGURES_DIR / "optimizatoriu_ir_aktyvaciju_palyginimas.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    additional = summary[summary["experiment"] == "additional"].copy()
    fig, ax = plt.subplots(figsize=(7.5, 4.5))
    positions = np.arange(len(additional))
    width = 0.36
    ax.bar(positions - width / 2, additional["accuracy_mean"] * 100, width, label="Tikslumas")
    ax.bar(positions + width / 2, additional["f1_mean"] * 100, width, label="F1")
    ax.set_xticks(positions, additional["configuration"], rotation=10, ha="right")
    ax.set_ylabel("Rodiklis, %")
    ax.set_ylim(50, 100)
    ax.grid(axis="y", alpha=0.25)
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIGURES_DIR / "papildomu_bandymu_palyginimas.png", dpi=300, bbox_inches="tight")
    plt.close(fig)


def summarize(results: pd.DataFrame) -> pd.DataFrame:
    metrics = ["accuracy", "precision", "recall", "f1", "roc_auc", "duration_seconds"]
    summary = results.groupby(["experiment", "configuration", "model"], as_index=False)[metrics].agg(
        ["mean", "std"]
    )
    summary.columns = [
        "_".join(value for value in column if value).rstrip("_")
        if isinstance(column, tuple)
        else column
        for column in summary.columns
    ]
    return summary


def checkpoint(rows: list[dict[str, object]]) -> None:
    pd.DataFrame(rows).to_csv(
        RESULTS_DIR / "tarpiniai_rezultatai.csv", index=False, encoding="utf-8-sig"
    )


def write_environment(x: np.ndarray, y: np.ndarray) -> None:
    class_counts = {str(int(label)): int((y == label).sum()) for label in np.unique(y)}
    environment = {
        "python": sys.version.split()[0],
        "tensorflow": tf.__version__,
        "scikit_learn": sklearn.__version__,
        "numpy": np.__version__,
        "platform": platform.platform(),
        "processor": platform.processor(),
        "dataset_rows": int(x.shape[0]),
        "dataset_features": int(x.shape[1]),
        "class_counts": class_counts,
        "split": "70/30 stratified",
        "seeds": SEEDS,
    }
    (RESULTS_DIR / "environment.json").write_text(
        json.dumps(environment, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--quick", action="store_true", help="Trumpas techninis patikrinimas")
    parser.add_argument(
        "--compact-only",
        action="store_true",
        help="Atlieka tik papildomą kompaktiško MLP bandymą ir sujungia rezultatus",
    )
    args = parser.parse_args()

    RESULTS_DIR.mkdir(exist_ok=True)
    FIGURES_DIR.mkdir(exist_ok=True)
    MODELS_DIR.mkdir(exist_ok=True)
    x, y = load_data()
    write_environment(x, y)

    if args.compact_only:
        existing_path = RESULTS_DIR / "visi_bandymu_rezultatai.csv"
        if not existing_path.exists():
            raise FileNotFoundError("Pirmiausia paleiskite visą eksperimentą.")
        existing = pd.read_csv(existing_path)
        compact_rows = []
        for seed in SEEDS:
            keep = seed == 42
            row, _, _, model = run_mlp(
                x,
                y,
                seed=seed,
                experiment="additional",
                configuration="MLP kompaktiškas 64-32-16",
                optimizer_name="adam",
                input_activation="relu",
                hidden_activation="relu",
                architecture="compact",
                standardize=True,
                epochs=100,
                keep_predictions=keep,
            )
            compact_rows.append(row)
            if keep:
                model.save(MODELS_DIR / "mlp_kompaktiskas_seed42.keras")
            print(f"Baigta: kompaktiškas MLP, sėkla {seed}, tikslumas {row['accuracy']:.4f}", flush=True)
        combined = pd.concat([existing, pd.DataFrame(compact_rows)], ignore_index=True)
        combined = combined.drop_duplicates(
            subset=["experiment", "configuration", "seed"], keep="last"
        )
        combined.to_csv(existing_path, index=False, encoding="utf-8-sig")
        checkpoint(combined.to_dict("records"))
        summary = summarize(combined)
        summary.to_csv(RESULTS_DIR / "rezultatu_santrauka.csv", index=False, encoding="utf-8-sig")
        save_summary_figures(summary)
        best = summary.sort_values("accuracy_mean", ascending=False).iloc[0].to_dict()
        comparison = {
            "article_reported_best_accuracy": ARTICLE_ACCURACY,
            "our_best_configuration": best["configuration"],
            "our_best_mean_accuracy": best["accuracy_mean"],
            "difference_percentage_points": (best["accuracy_mean"] - ARTICLE_ACCURACY) * 100,
            "important_limitation": (
                "Straipsnio Spambase imčių skaičiai sudaro 6098, nors oficialiame rinkinyje yra 4601; "
                "nepateikta atsitiktinė sėkla ir nepaaiškintas balansavimas."
            ),
        }
        (RESULTS_DIR / "palyginimas_su_straipsniu.json").write_text(
            json.dumps(comparison, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        return

    seeds = [42] if args.quick else SEEDS
    full_epochs = 3 if args.quick else 100
    architecture_epochs = 3 if args.quick else 50
    rows: list[dict[str, object]] = []

    configurations = [
        ("Nadam ReLU/ReLU", "nadam", "relu", "relu"),
        ("Adam ReLU/ReLU", "adam", "relu", "relu"),
        ("Adam sigmoid/sigmoid", "adam", "sigmoid", "sigmoid"),
        ("Adamax sigmoid/sigmoid", "adamax", "sigmoid", "sigmoid"),
        ("Nadam sigmoid/sigmoid", "nadam", "sigmoid", "sigmoid"),
        ("RMSprop sigmoid/sigmoid", "rmsprop", "sigmoid", "sigmoid"),
        ("Nadam ReLU/sigmoid", "nadam", "relu", "sigmoid"),
        ("RMSprop ReLU/sigmoid", "rmsprop", "relu", "sigmoid"),
        ("Adam ReLU/sigmoid", "adam", "relu", "sigmoid"),
        ("Adamax ReLU/sigmoid", "adamax", "relu", "sigmoid"),
    ]
    if args.quick:
        configurations = configurations[:2]
    for label, opt, input_act, hidden_act in configurations:
        for seed in seeds:
            row, _, _, _ = run_mlp(
                x,
                y,
                seed=seed,
                experiment="optimizer_activation",
                configuration=label,
                optimizer_name=opt,
                input_activation=input_act,
                hidden_activation=hidden_act,
                epochs=full_epochs,
            )
            rows.append(row)
            checkpoint(rows)
            print(f"Baigta: {label}, sėkla {seed}, tikslumas {row['accuracy']:.4f}", flush=True)

    for batch_size in [10, 32, 64]:
        for seed in seeds:
            row, _, _, _ = run_mlp(
                x,
                y,
                seed=seed,
                experiment="batch_size",
                configuration=f"Paketo dydis {batch_size}",
                batch_size=batch_size,
                epochs=full_epochs,
            )
            rows.append(row)
            checkpoint(rows)

    architectures = [
        ("Straipsnio A", "article_a"),
        ("Mažėjantys sluoksniai", "decrement"),
        ("Dropout prieš kiekvieną sluoksnį", "dropout_each"),
        ("Dropout prieš išvestį", "dropout_end"),
    ]
    if args.quick:
        architectures = architectures[:2]
    for label, architecture in architectures:
        for seed in seeds:
            row, _, _, _ = run_mlp(
                x,
                y,
                seed=seed,
                experiment="architecture",
                configuration=label,
                architecture=architecture,
                epochs=architecture_epochs,
            )
            rows.append(row)
            checkpoint(rows)

    final_predictions = {}
    for standardize, label in [(False, "MLP be standartizavimo"), (True, "MLP su standartizavimu")]:
        for seed in seeds:
            keep = seed == 42 and not standardize
            row, y_test, scores, model = run_mlp(
                x,
                y,
                seed=seed,
                experiment="additional",
                configuration=label,
                standardize=standardize,
                epochs=full_epochs,
                keep_predictions=keep,
            )
            rows.append(row)
            checkpoint(rows)
            if keep:
                final_predictions["mlp"] = (y_test, scores)
                model.save(MODELS_DIR / "mlp_straipsnio_parametrai_seed42.keras")

    for seed in seeds:
        keep = seed == 42
        row, _, _, model = run_mlp(
            x,
            y,
            seed=seed,
            experiment="additional",
            configuration="MLP kompaktiškas 64-32-16",
            optimizer_name="adam",
            input_activation="relu",
            hidden_activation="relu",
            architecture="compact",
            standardize=True,
            epochs=full_epochs,
            keep_predictions=keep,
        )
        rows.append(row)
        checkpoint(rows)
        if keep:
            model.save(MODELS_DIR / "mlp_kompaktiskas_seed42.keras")

    for seed in seeds:
        keep = seed == 42
        row, y_test, scores, model = run_svm(x, y, seed, keep_predictions=keep)
        rows.append(row)
        checkpoint(rows)
        if keep:
            final_predictions["svm"] = (y_test, scores)
            joblib.dump(model, MODELS_DIR / "svm_rbf_seed42.joblib")

    results = pd.DataFrame(rows)
    results.to_csv(RESULTS_DIR / "visi_bandymu_rezultatai.csv", index=False, encoding="utf-8-sig")
    summary = summarize(results)
    summary.to_csv(RESULTS_DIR / "rezultatu_santrauka.csv", index=False, encoding="utf-8-sig")
    save_summary_figures(summary)
    if "mlp" in final_predictions and "svm" in final_predictions:
        save_confusion_figure(*final_predictions["mlp"], *final_predictions["svm"])

    best = summary.sort_values("accuracy_mean", ascending=False).iloc[0].to_dict()
    comparison = {
        "article_reported_best_accuracy": ARTICLE_ACCURACY,
        "our_best_configuration": best["configuration"],
        "our_best_mean_accuracy": best["accuracy_mean"],
        "difference_percentage_points": (best["accuracy_mean"] - ARTICLE_ACCURACY) * 100,
        "important_limitation": (
            "Straipsnio Spambase imčių skaičiai sudaro 6098, nors oficialiame rinkinyje yra 4601; "
            "nepateikta atsitiktinė sėkla ir nepaaiškintas balansavimas."
        ),
    }
    (RESULTS_DIR / "palyginimas_su_straipsniu.json").write_text(
        json.dumps(comparison, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(comparison, ensure_ascii=False, indent=2), flush=True)


if __name__ == "__main__":
    main()
