import { useParams } from "react-router-dom";
import Comments from "./components/Comments";
import "@streamia/shared/styles/index.scss";

// Wrapper component that extracts movieId from URL params
export default function App() {
  const { id } = useParams<{ id: string }>();

  if (!id) {
    return <div className="comments-error">No se especificó una película</div>;
  }

  // TODO: Get token from shared store or context
  const token = localStorage.getItem("authToken") || undefined;

  return <Comments movieId={id} token={token} />;
}
