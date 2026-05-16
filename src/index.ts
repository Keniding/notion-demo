import { Worker } from "@notionhq/workers";
import { j } from "@notionhq/workers/schema-builder";

const worker = new Worker();
export default worker;

// ----------------------------------------------------------------------------
// HELPER — Notion API fetch con manejo de errores
// ----------------------------------------------------------------------------
async function notionFetch(endpoint: string, body: object) {
  const apiKey = process.env.API_KEY;
  const dbId   = process.env.DATABASE_ID;

  if (!apiKey) throw new Error("API_KEY is not set");
  if (!dbId)   throw new Error("DATABASE_ID is not set");

  const res = await fetch(`https://api.notion.com/v1${endpoint}`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Notion-Version": "2022-06-28",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const data = await res.json();

  // Log completo para diagnóstico
  console.log("Notion API response:", JSON.stringify(data, null, 2));

  // Si Notion devuelve error, lanzarlo explícitamente
  if (!res.ok || data.object === "error") {
    throw new Error(`Notion API error: ${data.code} — ${data.message}`);
  }

  return data;
}

worker.tool("sayHello", {
  title: "Say Hello",
  description: "Returns a friendly greeting for the given name.",
  schema: j.object({
    name: j.string().describe("The name to greet."),
  }),
  execute: ({ name }) => `Hello, ${name}!`,
});

// ============================================================================
// GESTIÓN DE PROYECTOS
// ============================================================================

worker.tool("createProject", {
  title: "Create Project",
  description: "Creates a new project and saves it to the Notion database.",
  schema: j.object({
    name:        j.string().describe("Project name."),
    description: j.string().describe("Short description of the project."),
    status:      j.enum("planning", "active", "on_hold", "completed", "cancelled")
                  .describe("Current status of the project."),
    priority:    j.enum("low", "medium", "high", "critical")
                  .describe("Priority level of the project."),
    owner:       j.string().describe("Name of the person responsible for the project."),
    due_date:    j.string().describe("Due date in YYYY-MM-DD format."),
  }),
  execute: async ({ name, description, status, priority, owner, due_date }) => {
    const page = await notionFetch("/pages", {
      parent: { database_id: process.env.DATABASE_ID },
      properties: {
        Name:        { title: [{ text: { content: name } }] },
        Description: { rich_text: [{ text: { content: description } }] },
        Status:      { select: { name: status } },
        Priority:    { select: { name: priority } },
        Owner:       { rich_text: [{ text: { content: owner } }] },
        "Due Date":  { date: { start: due_date } },
      },
    });

    return JSON.stringify({
      notion_url: (page as any).url,
      notion_id:  (page as any).id,
      name, status, priority, owner, due_date,
      message: `✅ Project "${name}" created in Notion!`,
    });
  },
});

worker.tool("updateProjectStatus", {
  title: "Update Project Status",
  description: "Updates the status of an existing project.",
  schema: j.object({
    project_name: j.string().describe("Name of the project to update."),
    new_status:   j.enum("planning", "active", "on_hold", "completed", "cancelled")
                   .describe("New status to assign to the project."),
    reason:       j.string().describe("Reason for the status change."),
  }),
  execute: ({ project_name, new_status, reason }) => {
    return JSON.stringify({
      project_name, new_status, reason,
      updated_at: new Date().toISOString(),
      message: `Project "${project_name}" status updated to "${new_status}".`,
    });
  },
});

worker.tool("createTask", {
  title: "Create Task",
  description: "Creates a task and assigns it to a project and a team member.",
  schema: j.object({
    title:        j.string().describe("Task title."),
    description:  j.string().describe("Detailed description of what needs to be done."),
    project_name: j.string().describe("Name of the project this task belongs to."),
    assignee:     j.string().describe("Name of the person assigned to this task."),
    priority:     j.enum("low", "medium", "high", "critical").describe("Task priority."),
    due_date:     j.string().describe("Due date in YYYY-MM-DD format."),
    tags:         j.array(j.string()).describe("List of tags or labels for the task."),
  }),
  execute: ({ title, description, project_name, assignee, priority, due_date, tags }) => {
    return JSON.stringify({
      id: `task_${Date.now()}`,
      title, description, project_name, assignee, priority, due_date, tags,
      status: "todo",
      created_at: new Date().toISOString(),
      message: `Task "${title}" created and assigned to ${assignee}.`,
    });
  },
});

worker.tool("updateTaskStatus", {
  title: "Update Task Status",
  description: "Moves a task to a different status in the workflow.",
  schema: j.object({
    task_title:  j.string().describe("Title of the task to update."),
    new_status:  j.enum("todo", "in_progress", "in_review", "blocked", "done")
                  .describe("New status for the task."),
    comment:     j.string().describe("Optional comment about the update."),
    updated_by:  j.string().describe("Name of the person making the update."),
  }),
  execute: ({ task_title, new_status, comment, updated_by }) => {
    return JSON.stringify({
      task_title, new_status, comment, updated_by,
      updated_at: new Date().toISOString(),
      message: `Task "${task_title}" moved to "${new_status}" by ${updated_by}.`,
    });
  },
});

worker.tool("getProjectSummary", {
  title: "Get Project Summary",
  description: "Returns a summary report of a project including task breakdown and progress.",
  schema: j.object({
    project_name:  j.string().describe("Name of the project to summarize."),
    total_tasks:   j.number().describe("Total number of tasks in the project."),
    done_tasks:    j.number().describe("Number of completed tasks."),
    in_progress:   j.number().describe("Number of tasks currently in progress."),
    blocked_tasks: j.number().describe("Number of blocked tasks."),
    team_members:  j.array(j.string()).describe("List of team members involved."),
  }),
  execute: ({ project_name, total_tasks, done_tasks, in_progress, blocked_tasks, team_members }) => {
    const progress = total_tasks > 0 ? Math.round((done_tasks / total_tasks) * 100) : 0;
    const health =
      blocked_tasks > 2 ? "at_risk" :
      progress >= 80    ? "on_track" :
      progress >= 40    ? "needs_attention" : "early_stage";

    return JSON.stringify({
      project_name, progress_percent: progress, health,
      task_breakdown: {
        total: total_tasks, done: done_tasks, in_progress,
        blocked: blocked_tasks,
        pending: total_tasks - done_tasks - in_progress - blocked_tasks,
      },
      team_members,
      generated_at: new Date().toISOString(),
      message: `Project "${project_name}" is ${progress}% complete — health: ${health}.`,
    });
  },
});

worker.tool("assignMember", {
  title: "Assign Member to Project",
  description: "Assigns a team member to a project with a specific role.",
  schema: j.object({
    project_name: j.string().describe("Name of the project."),
    member_name:  j.string().describe("Full name of the team member."),
    role:         j.enum("lead", "developer", "designer", "qa", "stakeholder", "observer")
                   .describe("Role of the member in the project."),
    start_date:   j.string().describe("Start date in YYYY-MM-DD format."),
  }),
  execute: ({ project_name, member_name, role, start_date }) => {
    return JSON.stringify({
      project_name, member_name, role, start_date,
      assigned_at: new Date().toISOString(),
      message: `${member_name} assigned to "${project_name}" as ${role}.`,
    });
  },
});

worker.tool("logBlocker", {
  title: "Log Blocker",
  description: "Registers a blocker or impediment affecting a task or project.",
  schema: j.object({
    title:       j.string().describe("Short title of the blocker."),
    description: j.string().describe("Detailed explanation of the blocker."),
    affects:     j.string().describe("Name of the task or project being blocked."),
    reported_by: j.string().describe("Name of the person reporting the blocker."),
    severity:    j.enum("low", "medium", "high", "critical").describe("How critical is this blocker."),
  }),
  execute: ({ title, description, affects, reported_by, severity }) => {
    return JSON.stringify({
      id: `blocker_${Date.now()}`,
      title, description, affects, reported_by, severity,
      status: "open",
      reported_at: new Date().toISOString(),
      message: `Blocker "${title}" logged for "${affects}" — severity: ${severity}.`,
    });
  },
});

worker.tool("getTeamReport", {
  title: "Get Team Report",
  description: "Generates a workload and performance report for a team.",
  schema: j.object({
    team_name: j.string().describe("Name of the team."),
    members: j.array(j.object({
      name:           j.string().describe("Member name."),
      tasks_assigned: j.number().describe("Total tasks assigned."),
      tasks_done:     j.number().describe("Tasks completed."),
      tasks_overdue:  j.number().describe("Tasks past due date."),
    })).describe("List of team members with their task stats."),
  }),
  execute: ({ team_name, members }) => {
    const report = members.map((m) => ({
      ...m,
      completion_rate: m.tasks_assigned > 0
        ? Math.round((m.tasks_done / m.tasks_assigned) * 100) : 0,
      status:
        m.tasks_overdue > 2                    ? "overloaded" :
        m.tasks_done / m.tasks_assigned >= 0.8 ? "performing" : "on_track",
    }));
    const avg = Math.round(report.reduce((a, m) => a + m.completion_rate, 0) / report.length);
    return JSON.stringify({
      team_name, avg_completion_rate: avg, members: report,
      generated_at: new Date().toISOString(),
      message: `Team "${team_name}" report — avg completion: ${avg}%.`,
    });
  },
});