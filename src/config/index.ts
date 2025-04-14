import { Character, ModelProviderName, settings, validateCharacterConfig } from "@elizaos/core";
import fs from "fs";
import path from "path";
import yargs from "yargs";

export function parseArguments(): {
  character?: string;
  characters?: string;
} {
  try {
    console.log('DEBUG: Parsing arguments:', process.argv);
    const args = yargs(process.argv.slice(2))
      .option("character", {
        type: "string",
        description: "Path to the character JSON file",
        demandOption: false,
        nargs: 1,
        alias: 'c'
      })
      .option("characters", {
        type: "string",
        description: "Comma separated list of paths to character JSON files",
        demandOption: false,
        nargs: 1,
        alias: 'cs'
      })
      .strict()
      .parseSync();
    console.log('DEBUG: Parsed arguments:', args);
    
    // Handle the case where the argument is passed as a positional argument
    if (args._ && args._.length > 0) {
      const firstArg = args._[0];
      if (firstArg.startsWith('--character=')) {
        args.character = firstArg.split('=')[1];
      } else if (firstArg === '--character' && args._.length > 1) {
        args.character = args._[1];
      }
    }
    
    return args;
  } catch (error) {
    console.error("Error parsing arguments:", error);
    return {};
  }
}

export async function loadCharacters(
  charactersArg: string
): Promise<Character[]> {
  console.log('DEBUG: loadCharacters called with arg:', charactersArg);
  let characterPaths = charactersArg?.split(",").map((filePath) => {
    console.log('DEBUG: Processing filepath:', filePath);
    if (path.basename(filePath) === filePath) {
      filePath = "../characters/" + filePath;
    }
    const resolvedPath = path.resolve(process.cwd(), filePath.trim());
    console.log('DEBUG: Resolved path:', resolvedPath);
    return resolvedPath;
  });

  console.log('DEBUG: Character paths:', characterPaths);
  const loadedCharacters = [];

  if (characterPaths?.length > 0) {
    for (const path of characterPaths) {
      try {
        console.log('DEBUG: Attempting to load character from:', path);
        const character = JSON.parse(fs.readFileSync(path, "utf8"));
        console.log('DEBUG: Successfully loaded character:', character.name);

        validateCharacterConfig(character);
        console.log('DEBUG: Character config validated for:', character.name);

        loadedCharacters.push(character);
      } catch (e) {
        console.error(`Error loading character from ${path}: ${e}`);
        // don't continue to load if a specified file is not found
        process.exit(1);
      }
    }
  }

  return loadedCharacters;
}

export function getTokenForProvider(
  provider: ModelProviderName,
  character: Character
) {
  switch (provider) {
    case ModelProviderName.OPENAI:
      return (
        character.settings?.secrets?.OPENAI_API_KEY || settings.OPENAI_API_KEY
      );
    case ModelProviderName.LLAMACLOUD:
      return (
        character.settings?.secrets?.LLAMACLOUD_API_KEY ||
        settings.LLAMACLOUD_API_KEY ||
        character.settings?.secrets?.TOGETHER_API_KEY ||
        settings.TOGETHER_API_KEY ||
        character.settings?.secrets?.XAI_API_KEY ||
        settings.XAI_API_KEY ||
        character.settings?.secrets?.OPENAI_API_KEY ||
        settings.OPENAI_API_KEY
      );
    case ModelProviderName.ANTHROPIC:
      return (
        character.settings?.secrets?.ANTHROPIC_API_KEY ||
        character.settings?.secrets?.CLAUDE_API_KEY ||
        settings.ANTHROPIC_API_KEY ||
        settings.CLAUDE_API_KEY
      );
    case ModelProviderName.REDPILL:
      return (
        character.settings?.secrets?.REDPILL_API_KEY || settings.REDPILL_API_KEY
      );
    case ModelProviderName.OPENROUTER:
      return (
        character.settings?.secrets?.OPENROUTER || settings.OPENROUTER_API_KEY
      );
    case ModelProviderName.GROK:
      return character.settings?.secrets?.GROK_API_KEY || settings.GROK_API_KEY;
    case ModelProviderName.HEURIST:
      return (
        character.settings?.secrets?.HEURIST_API_KEY || settings.HEURIST_API_KEY
      );
    case ModelProviderName.GROQ:
      return character.settings?.secrets?.GROQ_API_KEY || settings.GROQ_API_KEY;
  }
}
