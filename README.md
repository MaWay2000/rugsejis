# rugsejis — MATLAB Laboratory Work

[**Browse the project files**](https://github.com/MaWay2000/rugsejis) · [Laboratory 1 instructions](Lab%201/README.md) · [Laboratory 2 explanation](Lab%202/LAB2_PAAISKINIMAS.md)

A collection of MATLAB coursework, laboratory exercises, and supporting material. The repository includes classification/perceptron exercises, image-feature helpers, and neural-network training examples.

This is a source-and-coursework repository, not a hosted web application. Open the laboratory files in MATLAB to run the exercises.

## Repository contents

| Folder | Contents |
| --- | --- |
| [Lab 1](Lab%201/) | Perceptron/classification assignment, MATLAB files, data, and image-feature material. |
| [Lab 2](Lab%202/) | Neural-network training examples and a detailed Lithuanian explanation. |
| [Lab 3](Lab%203/) | Additional laboratory material. |
| [Lab 4](Lab%204/) | Additional laboratory material. |
| [Egzaminas](Egzaminas/) | Examination-related material. |

The individual laboratory instructions remain the primary reference for each assignment.

## Requirements

- MATLAB with support for the functions used by the selected exercise.
- The complete laboratory folder, including its input data and helper scripts.
- A writable working directory for scripts that produce figures or result files.

Requirements may differ between exercises. Read the script and its instructions before running it; do not assume that every example has identical MATLAB-version or toolbox requirements.

## Get started

```bash
git clone https://github.com/MaWay2000/rugsejis.git
cd rugsejis
```

Alternatively, use GitHub's **Code → Download ZIP** and extract the archive.

1. Open MATLAB.
2. Set the current folder to the laboratory you want to run.
3. Read that laboratory's instructions.
4. Open the relevant script, check its input paths, and run it from the editor.

For Laboratory 2, start with `Lab 2/start.m` and the [explanation](Lab%202/LAB2_PAAISKINIMAS.md). The separate `lab2.m` script contains extended experiments. Generated results are written to `lab2_rezultatai` by the relevant script, so preserve any outputs you want to keep before rerunning it.

## What the exercises cover

- **Laboratory 1:** classification and perceptron work, with data and image-feature helpers such as roundness and color calculations.
- **Laboratory 2:** small feed-forward neural networks, activation functions, backpropagation, training parameters, and visualized results.

See the original assignment documents for the exact tasks and expected outputs.

## Notes for changes

Keep original assignment text, input data, and working solutions intact unless the change specifically concerns them. When adjusting a script, state which laboratory and experiment it affects and record the MATLAB version used for checking it.

For a reproducible problem, [open an issue](https://github.com/MaWay2000/rugsejis/issues) with the script name, MATLAB version, error message, and the steps that produced it.
