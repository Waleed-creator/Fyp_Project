from sentence_transformers import SentenceTransformer, util
from transformers import pipeline
import torch
import logging

log = logging.getLogger("ToxicChecker")

class ToxicChecker:
    def __init__(self):
        self.embed_model = SentenceTransformer("all-MiniLM-L6-v2")

        device = 0 if torch.cuda.is_available() else -1
        self.tox_model = pipeline(
            "text-classification",
            model="unitary/toxic-bert",
            device=device
        )

        self.offensive_examples = [
            "i will kill you", "you are an idiot", "you are useless",
            "i will hurt you", "die", "shut up loser",
            "you stupid", "i hate you", "go to hell"
        ]

        self.off_emb = self.embed_model.encode(
            self.offensive_examples,
            convert_to_tensor=True,
            normalize_embeddings=True
        )

    def _clean(self, text):
        return text.lower().strip()

    def similarity(self, text):
        emb = self.embed_model.encode(
            self._clean(text),
            convert_to_tensor=True,
            normalize_embeddings=True
        )
        return float(util.cos_sim(emb, self.off_emb).max())

    def bert_score(self, text):
        res = self.tox_model(text[:512])[0]
        label = res["label"].lower()
        score = float(res["score"])
        return (score if "toxic" in label else 1 - score)

    def analyze(self, text):  # ✅ 4 spaces indent - class ke andar
        sim = self.similarity(text)
        bert = self.bert_score(text)

        lex = 0.0
        keywords = ["kill", "die", "stupid", "idiot", "hate", "hell", "useless"]
        for k in keywords:
            if k in text.lower():
                lex = 1.0
                break

        risk = (bert * 0.6 + sim * 0.3 + lex * 0.1) * 100
        flag = 1 if risk >= 70 else 0

        if risk >= 85:
            tox_label = "toxic"
        elif risk >= 75:
            tox_label = "harassment"
        elif risk >= 70:
            tox_label = "suspicious"
        else:
            tox_label = "none"

        return {
            "flag": flag,
            "tox_label": tox_label,
            "risk_score": round(risk, 2),
            "tox_score": round(bert, 4),
            "similarity_score": round(sim, 4),
            "lexicon_score": lex
        }