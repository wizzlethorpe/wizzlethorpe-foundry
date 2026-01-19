# Wizzlethorpe Labs for Foundry VTT

Tools for tabletop roleplayers, game masters, and worldbuilders.

## Features

### Quickbrush - AI Image Generation
Generate fantasy artwork for characters, creatures, items, and scenes directly in Foundry VTT.

- **Bring Your Own Key**: Use your OpenAI API key—you control costs and privacy
- **Reference images**: Upload up to 4 reference images for style/character consistency
- **Multiple types**: Characters, creatures, items, and scenes
- **Quality options**: Fast (gpt-image-1-mini) or High Quality (gpt-image-1)
- **Seamless integration**: Right-click menu on actors/items to generate images

### Bixby's Cocktails
Mix magical cocktails with unpredictable effects for your TTRPG sessions.

## Installation

In Foundry VTT, go to **Add-on Modules → Install Module** and paste:

```
https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/latest/download/module.json
```

Or install manually from the [GitHub releases page](https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases).

## Setup

1. Get your OpenAI API key from [platform.openai.com](https://platform.openai.com)
2. Open **Module Settings → Wizzlethorpe Labs**
3. Enter your OpenAI API key
4. (Optional) Choose your preferred image model

## Usage

### Generate Actor Images

1. Right-click on any Actor (character/NPC/creature)
2. Select **Generate Character Image** or **Generate Creature Image**
3. The description will auto-populate from the actor's bio/notes
4. Optionally add a context prompt or reference images
5. Click **Generate**
6. The generated image will be set as the actor's portrait automatically

### Generate Item Images

1. Right-click on any Item
2. Select **Generate Item Image**
3. Description auto-populates from item description
4. Adjust quality and aspect ratio as needed
5. Click **Generate**

## Subscription Tiers

Some features require a Patreon subscription. Link your account at [wizzlethorpe.com](https://wizzlethorpe.com).

| Feature | Free | Apprentice ($3) | Alchemist ($5) | Archmage ($10) |
|---------|------|-----------------|----------------|----------------|
| Character generation (BYOK) | ✓ | ✓ | ✓ | ✓ |
| Scene/Creature/Item gen (BYOK) | — | ✓ | ✓ | ✓ |
| Server-side generation | — | — | ✓ | ✓ |
| Weekly server quota | — | — | 10 | 25 |

## Pricing (BYOK Mode)

Uses your OpenAI API key—you only pay for what you use:

- **gpt-image-1-mini**: ~$0.01-0.05 per image (recommended)
- **gpt-image-1**: ~$0.03-0.15 per image (higher quality)

Check [OpenAI's pricing page](https://openai.com/pricing) for current rates.

## Support

- Website: [wizzlethorpe.com](https://wizzlethorpe.com)
- GitHub: [wizzlethorpe/wizzlethorpe-foundry](https://github.com/wizzlethorpe/wizzlethorpe-foundry)
- Issues: [GitHub Issues](https://github.com/wizzlethorpe/wizzlethorpe-foundry/issues)
- Email: bixby@wizzlethorpe.com

## License

MIT
