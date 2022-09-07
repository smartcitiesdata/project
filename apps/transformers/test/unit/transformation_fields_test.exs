defmodule Transformers.TransformationFieldsTest do
  use ExUnit.Case

  alias Transformers.TransformationFields

  test "return fields for remove transform" do
    assert TransformationFields.fields_for("remove") == Transformers.Remove.fields()
  end

  test "return fields for arithmetic_add transform" do
    assert TransformationFields.fields_for("arithmetic_add") ==
             Transformers.ArithmeticAdd.fields()
  end

  test "return fields for arithmetic_subtract transform" do
    assert TransformationFields.fields_for("arithmetic_subtract") ==
             Transformers.ArithmeticSubtract.fields()
  end

  test "returns empty array for unsupported transformations" do
    assert TransformationFields.fields_for("") == []
    assert TransformationFields.fields_for("nonsense") == []
  end
end
