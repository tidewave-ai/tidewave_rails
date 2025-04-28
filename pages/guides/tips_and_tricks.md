# Tips and tricks

Some tips and tricks to use Tidewave and AI assistants and agents effectively.

## Configure your prompts

Most editors and AI assistants allow you to write down a file that
is given as context to models. Such files are excellent places to
document your project's best practices, workflows, and pitfalls.
Keep this file short and to the point. For example, a Ruby on Rails
application may write:

```
This is a Ruby on Rails 8 application, which uses Tailwind and daisyUI.
Write tests for your changes and run `bin/rake test` afterwards.
```

## Use eval: AI's swiss army knife

AI assistants excel at coding. Since Tidewave can evaluate code within your
project, as well as execute commands in the terminal, you can ask the AI
to execute complex tasks through Tidewave's eval without a need for additional
tooling. With Tidewave, you can:

  * evaluate code within the project context
  * execute commands in the terminal
  * run SQL queries directly on your development database

This direct integration streamlines your workflow and keeps everything within
your existing development environment. For example, you no longer need to use
a separate tool to connect to your database, you can either execute SQL queries
directly or ask the agent to use your models and data schemas to load the data
in a more structured format.

Similarly, any API that your application talks to is automatically available
to agents, which can leverage your established authentication methods and
access patterns without requiring you to set up and maintain additional
development keys.

Furthermore, if you find yourself needing to automate workflows, you can
implement those as regular functions in your codebase and ask the agent to use
them, either explicitly or as part of your prompt. This keeps your tooling
consolidated and makes extending functionality a natural part of your development
process, like any other code you write.

In our experience, AI models become less effective when there are too many tools,
and work best with a few powerful ones. With Tidewave's eval, we make the power
of full programming languages within the context of your project available to
AI assistants.

## Plan and think ahead

Different AI assistants will require different techniques to produce the
best results but the majority of them will output better code if you ask
them to plan ahead.

AI assistants and editors may also provide a "think" tool, which often
improves the quality too. For example, Claude says:

> We recommend using the word "think" to trigger extended thinking mode,
> which gives Claude additional computation time to evaluate alternatives
> more thoroughly. These specific phrases are mapped directly to increasing
> levels of thinking budget in the system: "think" < "think hard" <
> "think harder" < "ultrathink." Each level allocates progressively more
> thinking budget for Claude to use.

- https://www.anthropic.com/engineering/claude-code-best-practices
