defmodule Expression.EvalTest do
  use ExUnit.Case, async: true
  alias Expression.Eval
  alias Expression.Parser

  test "substitution" do
    assert "bar" == Expression.evaluate_as_string!("@foo", %{"foo" => "bar"})
  end

  test "attributes on substitutions" do
    assert "baz" == Expression.evaluate_as_string!("@foo.bar", %{"foo" => %{"bar" => "baz"}})
  end

  test "attributes with literals" do
    assert "value" ==
             Expression.evaluate_as_string!("@foo.bar.123.baz", %{
               "foo" => %{
                 "bar" => %{
                   "123" => %{
                     "baz" => "value"
                   }
                 }
               }
             })
  end

  test "functions" do
    {:ok, ast, "", _, _, _} = Parser.parse(~s[@has_any_word("The Quick Brown Fox", "red fox")])

    assert %{"__value__" => true, "match" => "Fox"} == Eval.eval!(ast, %{})
  end

  test "if" do
    {:ok, ast, "", _, _, _} =
      Parser.parse("@if(image_response.status == 200,\nimage_response.body.id,\nfalse)")

    assert false ==
             Eval.eval!(ast, %{
               "image_response" => %{"status" => 500, "body" => "Internal Server Error"}
             })
  end

  describe "lambdas" do
    test "with map" do
      {:ok, ast, "", _, _, _} = Parser.parse("@map(foo, &([&1,'Button']))")

      assert [[1, "Button"], [2, "Button"], [3, "Button"]] ==
               Eval.eval!(ast, %{"foo" => [1, 2, 3]})
    end

    test "with functions" do
      {:ok, ast, "", _, _, _} = Parser.parse("@map(1..3, &date(2022, 5, &1))")

      assert [
               ~U[2022-05-01 00:00:00Z],
               ~U[2022-05-02 00:00:00Z],
               ~U[2022-05-03 00:00:00Z]
             ] == Eval.eval!(ast, %{})
    end

    test "with arithmatic" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(map(foo, &([&1, 'Button'])))")

      assert [[1, "Button"], [2, "Button"], [3, "Button"]] ==
               Eval.eval!(ast, %{"foo" => [1, 2, 3]})
    end

    test "lambda with joins" do
      assert [["one", "Button one"], ["two", "Button two"], ["three", "Button three"]] ==
               Expression.evaluate!("@map(choices, &([&1, 'Button ' & &1]))", %{
                 "choices" => ["one", "two", "three"]
               })
    end
  end

  test "email addresses" do
    assert "email info@one.two.three.four.five.six for more information" ==
             Expression.evaluate_as_string!(
               "email info@one.two.three.four.five.six for more information",
               %{}
             )
  end

  test "attributes on functions" do
    assert "Fox" ==
             Expression.evaluate_as_string!(
               ~s[@has_any_word("The Quick Brown Fox", "red fox").match],
               %{}
             )
  end

  describe "lists" do
    test "with literal indices" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[1]")

      assert 1 == Eval.eval!(ast, %{"foo" => [0, 1, 2]})
    end

    test "with function" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[day(now())]")
      today = DateTime.utc_now().day
      assert today == Eval.eval!(ast, %{"foo" => Enum.to_list(0..31)})
    end

    test "with range slices" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[1..3]")
      assert [1, 2, 3] == Eval.eval!(ast, %{"foo" => Enum.to_list(0..31)})
    end
  end

  test "arithmatic" do
    {:ok, ast, "", _, _, _} = Parser.parse("@(1 + 1)")
    assert 2 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(1 + 2 * 3)")
    assert 7 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@((1 + 2) * 3)")
    assert 9 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@((1 + 2) / 3)")
    assert 1.0 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(6 / 2 + 1)")
    assert 4.0 == Eval.eval!(ast, %{})
  end

  test "text" do
    assert "hello Bob" ==
             Expression.evaluate_as_string!("hello @contact.name", %{
               "contact" => %{"name" => "Bob"}
             })
  end
end
