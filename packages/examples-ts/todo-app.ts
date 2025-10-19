/**
 * Todo App Example
 * A functional todo list application showcasing interactivity
 */

import { createApp } from 'ts-zyte'

const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Zyte Todo App</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      padding: 2rem;
      color: #333;
    }

    .container {
      max-width: 600px;
      margin: 0 auto;
    }

    .header {
      text-align: center;
      color: white;
      margin-bottom: 2rem;
    }

    h1 {
      font-size: 3rem;
      margin-bottom: 0.5rem;
      text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.2);
    }

    .subtitle {
      font-size: 1.1rem;
      opacity: 0.9;
    }

    .todo-card {
      background: white;
      border-radius: 15px;
      box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
      padding: 2rem;
    }

    .input-group {
      display: flex;
      gap: 0.5rem;
      margin-bottom: 1.5rem;
    }

    input[type="text"] {
      flex: 1;
      padding: 0.8rem 1rem;
      border: 2px solid #e0e0e0;
      border-radius: 8px;
      font-size: 1rem;
      outline: none;
      transition: border-color 0.2s;
    }

    input[type="text"]:focus {
      border-color: #667eea;
    }

    button {
      padding: 0.8rem 1.5rem;
      background: #667eea;
      color: white;
      border: none;
      border-radius: 8px;
      font-size: 1rem;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s;
    }

    button:hover {
      background: #5568d3;
    }

    .todo-list {
      list-style: none;
    }

    .todo-item {
      display: flex;
      align-items: center;
      padding: 1rem;
      border-bottom: 1px solid #f0f0f0;
      transition: background 0.2s;
    }

    .todo-item:hover {
      background: #f8f9fa;
    }

    .todo-item:last-child {
      border-bottom: none;
    }

    .todo-checkbox {
      width: 20px;
      height: 20px;
      margin-right: 1rem;
      cursor: pointer;
    }

    .todo-text {
      flex: 1;
      font-size: 1rem;
    }

    .todo-item.completed .todo-text {
      text-decoration: line-through;
      opacity: 0.5;
    }

    .delete-btn {
      padding: 0.3rem 0.8rem;
      background: #ff6b6b;
      font-size: 0.9rem;
    }

    .delete-btn:hover {
      background: #ee5a52;
    }

    .empty-state {
      text-align: center;
      padding: 3rem 1rem;
      color: #999;
    }

    .empty-state-icon {
      font-size: 4rem;
      margin-bottom: 1rem;
    }

    .stats {
      margin-top: 1.5rem;
      padding-top: 1.5rem;
      border-top: 1px solid #e0e0e0;
      text-align: center;
      color: #666;
      font-size: 0.9rem;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>✓ Todo List</h1>
      <p class="subtitle">Stay organized with Zyte</p>
    </div>

    <div class="todo-card">
      <div class="input-group">
        <input type="text" id="todoInput" placeholder="What needs to be done?" autofocus>
        <button onclick="addTodo()">Add</button>
      </div>

      <ul class="todo-list" id="todoList"></ul>

      <div class="stats">
        <span id="stats">No tasks yet</span>
      </div>
    </div>
  </div>

  <script>
    let todos = []

    function addTodo() {
      const input = document.getElementById('todoInput')
      const text = input.value.trim()

      if (text) {
        todos.push({ id: Date.now(), text, completed: false })
        input.value = ''
        render()
      }
    }

    function toggleTodo(id) {
      const todo = todos.find(t => t.id === id)
      if (todo) {
        todo.completed = !todo.completed
        render()
      }
    }

    function deleteTodo(id) {
      todos = todos.filter(t => t.id !== id)
      render()
    }

    function render() {
      const list = document.getElementById('todoList')
      const stats = document.getElementById('stats')

      if (todos.length === 0) {
        list.innerHTML = \`
          <div class="empty-state">
            <div class="empty-state-icon">📝</div>
            <p>No tasks yet. Add one above to get started!</p>
          </div>
        \`
        stats.textContent = 'No tasks yet'
      } else {
        list.innerHTML = todos.map(todo => \`
          <li class="todo-item \${todo.completed ? 'completed' : ''}">
            <input
              type="checkbox"
              class="todo-checkbox"
              \${todo.completed ? 'checked' : ''}
              onchange="toggleTodo(\${todo.id})"
            >
            <span class="todo-text">\${todo.text}</span>
            <button class="delete-btn" onclick="deleteTodo(\${todo.id})">Delete</button>
          </li>
        \`).join('')

        const active = todos.filter(t => !t.completed).length
        const completed = todos.filter(t => t.completed).length
        stats.textContent = \`\${active} active, \${completed} completed\`
      }
    }

    // Add todo on Enter key
    document.getElementById('todoInput').addEventListener('keypress', (e) => {
      if (e.key === 'Enter') {
        addTodo()
      }
    })

    // Initial render
    render()
  </script>
</body>
</html>
`

const app = createApp({
  html,
  window: {
    title: 'Zyte Todo App',
    width: 700,
    height: 800,
    resizable: true,
  },
})

await app.show()
