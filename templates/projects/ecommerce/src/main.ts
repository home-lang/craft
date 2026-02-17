/**
 * E-commerce Template - {{appName}}
 * A cross-platform shopping app built with Craft
 */

import { db, window, Platform, haptics } from '@stacksjs/ts-craft'

// Types
interface Product {
  id: string
  name: string
  description: string
  price: number
  image: string
  category: string
  inStock: boolean
}

interface CartItem {
  product: Product
  quantity: number
}

// State
let products: Product[] = []
let cart: CartItem[] = []
let currentView: 'home' | 'cart' | 'product' = 'home'
let selectedProductId: string | null = null

// Initialize
async function init(): Promise<void> {
  await initDatabase()
  await loadProducts()

  window.setTitle('{{appName}}')
  window.setSize(400, 800)

  render()
}

async function initDatabase(): Promise<void> {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS cart (
      productId TEXT PRIMARY KEY,
      quantity INTEGER DEFAULT 1
    )
  `)
}

async function loadProducts(): Promise<void> {
  // Sample products - replace with API call
  products = [
    { id: '1', name: 'Product 1', description: 'Description', price: 29.99, image: '', category: 'Category', inStock: true },
    { id: '2', name: 'Product 2', description: 'Description', price: 49.99, image: '', category: 'Category', inStock: true },
    { id: '3', name: 'Product 3', description: 'Description', price: 19.99, image: '', category: 'Category', inStock: false },
  ]
}

// Cart functions
function addToCart(productId: string): void {
  const product = products.find(p => p.id === productId)
  if (!product) return

  const existingItem = cart.find(item => item.product.id === productId)
  if (existingItem) {
    existingItem.quantity++
  } else {
    cart.push({ product, quantity: 1 })
  }

  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    haptics.notification('success')
  }

  render()
}

function removeFromCart(productId: string): void {
  cart = cart.filter(item => item.product.id !== productId)
  render()
}

function getCartTotal(): number {
  return cart.reduce((sum, item) => sum + (item.product.price * item.quantity), 0)
}

// Navigation
function navigate(view: typeof currentView, productId?: string): void {
  currentView = view
  selectedProductId = productId || null
  render()
}

// Render
function render(): void {
  const app = document.getElementById('app')
  if (!app) return

  let content = ''
  switch (currentView) {
    case 'home':
      content = renderHome()
      break
    case 'cart':
      content = renderCart()
      break
    case 'product':
      content = renderProduct()
      break
  }

  app.innerHTML = `
    <div class="app">
      <header class="header">
        <h1>{{appName}}</h1>
        <button class="cart-btn" onclick="navigate('cart')">
          🛒 ${cart.length}
        </button>
      </header>
      <main>${content}</main>
      <nav class="bottom-nav">
        <button onclick="navigate('home')" class="${currentView === 'home' ? 'active' : ''}">Home</button>
        <button onclick="navigate('cart')" class="${currentView === 'cart' ? 'active' : ''}">Cart</button>
      </nav>
    </div>
  `
}

function renderHome(): string {
  return `
    <div class="products-grid">
      ${products.map(product => `
        <div class="product-card" onclick="navigate('product', '${product.id}')">
          <div class="product-image"></div>
          <h3>${product.name}</h3>
          <p class="price">$${product.price.toFixed(2)}</p>
          <button onclick="event.stopPropagation(); addToCart('${product.id}')"
                  ${!product.inStock ? 'disabled' : ''}>
            ${product.inStock ? 'Add to Cart' : 'Out of Stock'}
          </button>
        </div>
      `).join('')}
    </div>
  `
}

function renderCart(): string {
  if (cart.length === 0) {
    return `<div class="empty-state"><p>Your cart is empty</p></div>`
  }

  return `
    <div class="cart">
      ${cart.map(item => `
        <div class="cart-item">
          <span>${item.product.name} x${item.quantity}</span>
          <span>$${(item.product.price * item.quantity).toFixed(2)}</span>
          <button onclick="removeFromCart('${item.product.id}')">Remove</button>
        </div>
      `).join('')}
      <div class="cart-total">
        <strong>Total: $${getCartTotal().toFixed(2)}</strong>
      </div>
      <button class="checkout-btn">Checkout</button>
    </div>
  `
}

function renderProduct(): string {
  const product = products.find(p => p.id === selectedProductId)
  if (!product) return '<p>Product not found</p>'

  return `
    <div class="product-detail">
      <button onclick="navigate('home')">← Back</button>
      <div class="product-image large"></div>
      <h2>${product.name}</h2>
      <p>${product.description}</p>
      <p class="price">$${product.price.toFixed(2)}</p>
      <button onclick="addToCart('${product.id}')" ${!product.inStock ? 'disabled' : ''}>
        ${product.inStock ? 'Add to Cart' : 'Out of Stock'}
      </button>
    </div>
  `
}

// Expose functions globally
(window as any).navigate = navigate
;(window as any).addToCart = addToCart
;(window as any).removeFromCart = removeFromCart

// Start app
init()
