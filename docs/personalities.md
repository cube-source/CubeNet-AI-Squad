# Personality Engine & Behavioral Logic

The Personality Engine is the cognitive layer of CubeNet AI Squad. While the Core handles *who* a bot is (identity), the Personality Engine defines *how* that bot behaves. By moving away from generic "Skill Levels," we implement a weight-based trait system that creates distinct, recognizable digital personas.

## 🧠 The Trait Architecture

Every bot profile in the SQLite database is associated with a set of behavioral weights. These weights act as multipliers for the bot's decision-making logic within the Source Engine.

### Core Behavioral Vectors

| Trait | Definition | Impact on Gameplay |
| :--- | :--- | :--- |
| **Aggression** | The drive to seek out and engage enemies. | High aggression bots push forward and prioritize kills over cover. |
| **Bravery** | The threshold for retreating from danger. | Low bravery bots will retreat to health packs or teammates when low on HP. |
| **Objective Focus** | The priority given to map objectives (Control Points/Payload). | High focus bots ignore peripheral fights to secure the objective. |
| **Sociality** | The frequency and type of communication triggered. | Influences how often a bot uses the Voice System based on event triggers. |

## ⚙️ Implementation Logic: Weight-Based Decisioning

The engine doesn't use simple "if/else" logic for behavior. Instead, it calculates a **Probability Score** for various actions.

**Example: Engagement Decision**
When an enemy is spotted, the bot calculates its action based on:
`ActionScore = (Aggression * 0.6) + (Bravery * 0.4) - (CurrentHP_Penalty)`

*   If `ActionScore > Threshold`: **Engage Target**
*   If `ActionScore < Threshold`: **Seek Cover / Support**

## 🎭 Personality Archetypes

To simplify configuration, we utilize "Archetypes" as templates for these weights:

*   **The Vanguard:** High Aggression, High Bravery, Moderate Objective Focus. (The frontline bruiser).
*   **The Tactician:** Moderate Aggression, Moderate Bravery, High Objective Focus. (The objective-driven anchor).
*   **The Skirmisher:** High Aggression, Low Bravery, Low Objective Focus. (The hit-and-run specialist).

## 🛠️ Configuration via `personalities.cfg`

Personalities are defined in the `configs/cubenet_ai/personalities.cfg` file using a KeyValues format:

```kv
"BotProfiles"
{
    "Vanguard"
    {
        "aggression" "0.9"
        "bravery" "0.8"
        "obj_focus" "0.5"
    }
    "Tactician"
    {
        "aggression" "0.4"
        "bravery" "0.6"
        "obj_focus" "0.9"
    }
}
```

## 🚀 Future Evolution: Learning & Adaptation

The long-term vision for the Personality Engine is **Dynamic Weight Adjustment**. By analyzing the SQLite statistics (Kills/Deaths/Objective time), the engine will subtly shift weights over time:
*   A bot that consistently dies while pushing will see a slight decrease in `Bravery`.
*   A bot that successfully secures points will increase its `Objective Focus` weight.

This transforms the AI from a static script into an evolving teammate that adapts to the server's meta.
