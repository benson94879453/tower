import os

folder = r"c:\Users\user\Documents\GitHub\0406\tower\scripts\battle"

replacements = {
    "CombatantDataClass": "CombatantData",
    "TurnStrategyClass": "TurnStrategy",
    "DamageCalculatorClass": "DamageCalculator",
    "SkillExecutorClass": "SkillExecutor",
    "StatusProcessorClass": "StatusProcessor",
    "PassiveProcessorClass": "PassiveProcessor",
    "AccessoryProcessorClass": "AccessoryProcessor",
    "ThemeConstantsClass": "ThemeConstants",
    "BattleAIClass": "BattleAI",
    "BattleResultClass": "BattleResult",
    "TurnManagerClass": "TurnManager"
}

for root, _, files in os.walk(folder):
    for f in files:
        if f.endswith(".gd"):
            filepath = os.path.join(root, f)
            with open(filepath, "r", encoding="utf-8") as file:
                content = file.read()
            
            # Remove preload lines
            lines = content.split('\n')
            new_lines = []
            for line in lines:
                if "preload" in line and any(k in line for k in replacements.keys()):
                    continue
                new_lines.append(line)
            content = '\n'.join(new_lines)
            
            # Replace usages
            for k, v in replacements.items():
                content = content.replace(k, v)
                
            with open(filepath, "w", encoding="utf-8") as file:
                file.write(content)

folder = r"c:\Users\user\Documents\GitHub\0406\tower\scripts\autoload"
# Same for autoload if they use it... actually I think I only need battle scripts.
print("Done!")
