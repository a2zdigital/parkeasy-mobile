# Design Principles

## The four principles

| Principle | In practice |
|---|---|
| **Discovery first** | Nearby parking, distance, price and availability are scannable in one glance. The list and the map show the same results and never compete. |
| **Trust through clarity** | Before the user commits they see the total price, the exact start and end, the payment mode, whether the booking is instant or needs the owner's approval, and the cancellation rule. |
| **Fast, low-friction actions** | One primary action per screen. Sensible defaults (now, two hours, car). Predictable navigation. |
| **One coherent system** | Customers and owners share brand, type and components. Each role gets its own navigation; owner work is never squeezed into the customer's tabs. |

## Engineered, not generated

These rules are what separates a product from a mock-up. They are checked in review.

1. **Tokens only.** A widget contains no colour, font size, spacing, radius, duration or shadow literal. If the value you need is not a token, the design is wrong or the token set is: raise it, do not invent one.
2. **Every component has every state.** Default, pressed, focused, disabled, loading, error. A component without its states is not finished.
3. **Every screen has every state.** Loading, empty, error, data, and for lists: more loading and end of list. Design them before writing the happy path.
4. **Real data shapes the layout.** Build with a 48-character facility name, ₹1,25,000.00, a booking across midnight, zero results, one result, 200% text size. Not with the neat sample from the mock-up.
5. **Nothing decorative.** No gradient, glow, glass effect, illustration or animation that does not carry information or feedback. Elevation appears only where something really floats above the page.
6. **Hierarchy by type and space, not by colour.** Most of a screen is neutral. Electric blue marks what can be pressed or what is selected. If a screen has more than one filled blue button, one of them is wrong.
7. **Status means the server's status.** A chip shows what the API returned, with a label and an icon. Booking status, payment status and refund status are separate facts and are never merged into one badge.
8. **The app does not pretend.** No feature the API does not have, no fake rating, no placeholder count. A missing capability is absent, not mocked.
9. **Consistent rhythm.** Screen padding, section gaps and card padding are the same on every screen. A reviewer should not be able to tell which developer built which screen.
10. **Feedback within 100 ms.** Every press shows a pressed state at once. Anything slower than 300 ms shows progress. Nothing can be pressed twice.
11. **Accessible by construction.** Contrast pairs are fixed in the tokens, targets are 48 by 48, every control has a label, colour is never the only signal.
12. **Light theme first.** The first version ships light only. Tokens are semantic (`surface`, `textPrimary`), so a dark theme is a second set of values later, not a rewrite.
