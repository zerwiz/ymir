# Model Configuration Rules

## Rule 1: Tool Support Requirement
**Every model configuration that is intended for use with tool-capable systems MUST include explicit guidance for tool usage.**

### Implementation:
All model configurations (Ollama Modelfiles, llama.cpp configurations, Docker setups) must include:
1. System prompt guidance that mentions available tools
2. Examples of how to invoke tools when appropriate
3. Clear instructions on tool parameters and return values

### Examples:
- Ollama Modelfiles: Include tool usage instructions in the SYSTEM section
- llama.cpp configurations: Provide sample prompts that demonstrate tool usage
- Docker configurations: Document how to configure the host system for tool access

## Rule 2: Configuration Documentation
**Every model configuration MUST have corresponding documentation in the appropriate service/tool directory, including WORKING.md and NOT_WORKING.md files.**

### Implementation:
For each combination of:
- Hosting service (ollama, llama_cpp, docker)
- Target environment/tool (opencode, pi, zed)

There must exist:
1. A README.md file explaining the configuration
2. A WORKING.md file documenting verified working configurations
3. A NOT_WORKING.md file documenting configurations needing testing or with known issues
4. Any necessary configuration files (Modelfile, docker-compose.yml, etc.)
5. Documentation of expected behavior and performance characteristics

## Rule 3: Working vs Non-Working Distinction
**Configurations MUST be clearly marked as either WORKING or REQUIRES_TESTING/NOT_WORKING in the appropriate documentation files.**

### Implementation:
- Working configurations: Documented in WORKING.md with ✅ status
- Not working or untested configurations: Documented in NOT_WORKING.md with 🔄 status
- All configuration files should reference the appropriate documentation files

## Rule 4: System-Specific Optimization
**All configurations MUST be optimized for the target system specifications.**

### System Specifications (Precision 7560):
- 128 GiB RAM
- 11th Gen Intel Core i9-11950H × 16
- NVIDIA RTX A5000 Laptop GPU
- Ubuntu 24.04.4 LTS

### Implementation:
- Ollama configurations: Leverage abundant RAM for larger context sizes
- Docker configurations: Utilize GPU acceleration when available
- llama.cpp configurations: Compile with CPU-specific optimizations (AVX2, FMA)
- All configurations: Monitor thermal characteristics to prevent throttling

## Rule 5: Tool Integration Verification
**Configurations claiming tool support MUST be verified to actually work with tools.**

### Implementation:
- Test configurations with actual tool usage scenarios
- Document any limitations or special requirements for tool usage
- Provide examples of successful tool interactions
- Note any prompting techniques that improve tool utilization

## Applying These Rules

### For New Configurations:
1. Create directory structure: [service]/[tool]/
2. Add necessary configuration files (Modelfile, docker-compose.yml, etc.)
3. Create README.md with documentation
4. Create WORKING.md and NOT_WORKING.md files
5. Test the configuration for tool support
6. Document as WORKING or NOT_WORKING in the appropriate file
7. Ensure optimizations match system specifications

### For Existing Configurations:
1. Verify each has corresponding README.md, WORKING.md, and NOT_WORKING.md
2. Check for tool usage guidance in system prompts
3. Confirm system-specific optimizations
4. Update documentation to reflect WORKING/NOT_WORKING status
5. Add missing elements to comply with rules