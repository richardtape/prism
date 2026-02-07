# Phase 08: Speaker ID Model Training + Core ML Integration

**Overview**
Train (or fine-tune) a speaker-embedding model offline, export to Core ML, and integrate it into the app for high-quality on-device speaker identification.

**Scope**
In scope:
- Offline training or fine-tuning workflow for a speaker-embedding model.
- Export and validation of a Core ML model for on-device inference.
- Integration plan for replacing the stub embedding extractor in Prism.
- Evaluation methodology for speaker ID accuracy and false positives.

Out of scope:
- In-app training or personalization.
- Continuous model updates shipped over the network.

**Dependencies**
- Offline ML environment (Python, PyTorch or TensorFlow).
- Labeled speaker dataset for training and validation.
- Core ML Tools for model conversion.

**Design**
- Model produces a fixed-length embedding vector per audio segment.
- Embeddings are compared via cosine similarity against enrolled profiles.
- Thresholds are tuned using validation data to balance false positives/negatives.

**Training Workflow**
1. **Select a baseline architecture** (e.g., ECAPA-TDNN or ResNet-based speaker embedding).
2. **Prepare dataset** with labeled speakers and multiple recordings per speaker.
3. **Train or fine-tune** the model on the dataset.
4. **Validate** on held-out speakers to estimate verification accuracy (EER, ROC).
5. **Export** the trained model to Core ML.
6. **Run on-device validation** to ensure inference speed and accuracy.

**Integration Steps**
1. Add the Core ML model (`.mlmodel` or `.mlpackage`) to the app target.
2. Replace `StubSpeakerEmbeddingModel` with a Core ML-backed extractor.
3. Normalize and pre-process audio to match training conditions.
4. Re-tune `speakerId.matchThreshold` based on real embeddings.

**Evaluation**
- Track true accept rate (TAR) and false accept rate (FAR).
- Test household scenarios with similar voices.
- Validate with short and long utterances.

**Risks & Open Questions**
- Model accuracy depends heavily on data quality and diversity.
- Conversion to Core ML may require ops compatibility adjustments.
- Short utterances can reduce embedding stability; minimum duration may be required.
